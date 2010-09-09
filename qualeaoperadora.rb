require 'rubygems'
require 'mechanize'
require 'open-uri'
require 'vendor/haml/lib/haml.rb'
require 'vendor/sinatra/lib/sinatra.rb'

class Telefone
    attr_reader :ddd, :numero, :operadora
    def initialize(numero)
        @numero = numero
        @ddd = numero[0..1]
        @numero = "(#{@ddd})#{numero[2..5]}.#{numero[6..-1]}" if numero.length < 13

        url = "http://consultanumero.abr.net.br:8080/consultanumero/consulta/consultaSituacaoAtual!carregar.action"
        url_captcha = "http://consultanumero.abr.net.br:8080/consultanumero/jcaptcha.jpg?jcid="

        ag = WWW::Mechanize.new
        ag.user_agent = "Mozilla/5.0 (X11; U; Linux i686; en-US) AppleWebKit/533.4 (KHTML, like Gecko) Ubuntu/10.04 Chromium/5.0.375.127 Chrome/5"

        page = ag.get(url)
        form = page.forms[0]

        open('/tmp/captcha.jpg', 'w+') do |captcha|
            captcha.puts open(url_captcha + form['jcid']).read()
        end
        captcha_text = `vendor/gocr/gocr -C A-Z0-9 -m 2 -p vendor/gocr/db/ /tmp/captcha.jpg`.strip

        form['nmTelefone'] = @numero
        form['j_captcha_response'] = captcha_text

        params = { 'nmTelefone' => form['nmTelefone'],
                   'j_captcha_response'=> form['j_captcha_response'],
                   'jcid' => form['jcid'], 'method:consultar' => 'Consultar' }

        page = ag.post(url, params, 'Cookie' => "JSESSIONID=#{form['j_captcha_response']}").body

        operadora_end = page[4462..4480] =~ /</
        if operadora_end
            @operadora = page[4462...4462+operadora_end]
            @operadora = @operadora.unpack('C*').pack('U*')
        end

        @operadora = "desconhecida" if not operadora_end or operadora =~ /t[br].*/
    end

    def logotipo
        return "oi.jpg"          if @operadora =~ /Oi/i
        return "tim.jpg"         if @operadora =~ /Tim/i
        return "gvt.jpg"         if @operadora =~ /GVT/i
        return "ctbc.jpg"        if @operadora =~ /CTBC/i
        return "vivo.jpg"        if @operadora =~ /Vivo/i
        return "claro.jpg"       if @operadora =~ /Claro/i
        return "tleste.jpg"      if @operadora =~ /T-Leste/i
        return "embratel.jpg"    if @operadora =~ /Embratel/i
        return "sercomtel.jpg"   if @operadora =~ /Sercomtel/i
        return "telefonica.jpg"  if @operadora =~ /Telefonica/i
    end

    def uf
        case @ddd.to_i
        when 11..19: "SP"
        when 21, 22, 24: "RJ"
        when 27, 28: "ES"
        when 31..35, 37, 38: "MG"
        when 41..46: "PR"
        when 47..49: "SC"
        when 51, 53..55: "RS"
        when 61: "DF"
        when 62, 64: "GO"
        when 63: "TO"
        when 65, 66: "MT"
        when 67: "MS"
        when 68: "AC"
        when 69: "RO"
        when 71, 73..75, 77: "BA"
        when 79: "SE"
        when 81, 87: "PE"
        when 82: "AL"
        when 83: "PB"
        when 84: "RN"
        when 85, 88: "CE"
        when 86, 89: "PI"
        when 91, 93, 94: "PA"
        when 92, 97: "AM"
        when 95: "RR"
        when 96: "AP"
        when 98, 99: "MA"
        end
    end
end


get %r{/(\d{10})(\..+)?$} do |numero, extensao|
    telefone = Telefone.new(numero)
    @uf = telefone.uf
    @numero = telefone.numero
    @operadora = telefone.operadora
    @logotipo = "http://qualeaoperadora.de/images/#{telefone.logotipo}"
    print "[#{Time.new.utc}] #{@numero} => #{@operadora} (#{@uf})"
    case extensao
        when '.yml', '.yaml'
            puts ' [yml]'
            return @operadora
        when '.json'
            puts ' [json]'
            params[:callback] = 'jsonOperadora' if not params[:callback]
            jsonp = "#{params[:callback]}({\"operadora\": \"#{@operadora}\",
                                           \"logotipo\": \"#{@logotipo}\",
                                           \"uf\": \"#{@uf}\"})"
            return jsonp
        else
            puts ' [html]'
            haml :operadora
    end
end

get '/' do
    haml :index
end

post '/' do
    Telefone.new(params[:numero]).operadora
end

not_found do
    redirect '/'
end
