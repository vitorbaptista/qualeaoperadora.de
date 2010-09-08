require 'rubygems'
require 'mechanize'
require 'open-uri'
require 'vendor/haml/lib/haml.rb'
require 'vendor/sinatra/lib/sinatra.rb'

class Telefone
    attr_reader :numero, :operadora
    def initialize(numero)
        @numero = numero
        @numero = "(#{numero[0..1]})#{numero[2..5]}.#{numero[6..-1]}" if numero.length < 13

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

        page = `curl -d "nmTelefone=#{form['nmTelefone']}&j_captcha_response=#{form['j_captcha_response']}&jcid=#{form['jcid']}&method:consultar=Consultar" -b "JSESSIONID=#{form['j_captcha_response']}" #{url}`

        operadora_end = page[4462..4480] =~ /</
        if operadora_end
            @operadora = page[4462...4462+operadora_end]
            @operadora = @operadora.unpack('C*').pack('U*')
        end

        @operadora = "Desconhecida" if not operadora_end or operadora =~ /t[br].*/
    end

    def logotipo
        return "images/oi.jpg"    if @operadora =~ /Oi/i
        return "images/tim.jpg"   if @operadora =~ /Tim/i
        return "images/vivo.jpg"  if @operadora =~ /Vivo/i
        return "images/claro.jpg" if @operadora =~ /Claro/i
    end
end


get %r{/(\d{10})(\..+)?$} do |numero, extensao|
    telefone = Telefone.new(numero)
    @numero = telefone.numero
    @operadora = telefone.operadora
    @logotipo = telefone.logotipo
    case extensao
        when '.yml', '.yaml'
            return @operadora
        when '.json'
            params[:callback] = 'jsonOperadora' if not params[:callback]
            jsonp = "#{params[:callback]}({\"operadora\": \"#{@operadora}\",
                                           \"logotipo\": \"#{@logotipo}\"})"
            return jsonp
        else
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
