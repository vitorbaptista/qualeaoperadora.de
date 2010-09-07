require 'rubygems'
require 'mechanize'
require 'open-uri'
require 'haml'
require 'vendor/sinatra/lib/sinatra.rb'

class Telefone
    attr_reader :numero, :operadora
    def initialize(numero)
        @numero = numero
        @numero = "(#{numero[0..1]})#{numero[2..5]}.#{numero[6..-1]}" if numero.length < 13

        url = "http://consultanumero.abr.net.br:8080/consultanumero/consulta/consultaSituacaoAtual!carregar.action"
        url_captcha = "http://consultanumero.abr.net.br:8080/consultanumero/jcaptcha.jpg?jcid="

        ag = Mechanize.new
        ag.user_agent = "Mozilla/5.0 (Windows; U; Windows NT 5.1; pt-BR; rv:1.8.0.1) Gecko/20060111 Firefox/1.5.0.1"

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


get %r{/(\d{10})$} do |numero|
    telefone = Telefone.new(numero)
    @numero = telefone.numero
    @operadora = telefone.operadora
    @logotipo = telefone.logotipo
    haml :operadora
end

get '/' do
    haml :index
end

get '/*' do
    redirect '/'
end

post '/' do
    Telefone.new(params[:numero]).operadora
end

__END__
@@ layout
!!! Strict
%html
  %head
    %meta{'http-equiv' => 'Content-Type', :content => 'text/html; charset=utf-8'}/
    :css
      body{background-color:#fff;color:#333;font-family:Arial,Verdana,sans-serif;font-size:62.5%;margin:10% 5% 0 5%;text-align:center;}
      a,a:visited,a:active{color:#0080ff;text-decoration:underline;}
      a:hover{text-decoration:none;}
      input[type=text]{border:1px solid #ccc;color:#ccc;font-size:1em;padding:4px 6px 4px 6px;}
      .domain{font-weight:bold;}
      a.adlink{color: orange;}
      #container{clear:both;font-size:3em;margin:auto;}
      #numero_input{width:172px;}
    :javascript
      function clearInput(e) {
        if (e.cleared) { return; }
        e.cleared = true;
        e.value = '';
        e.style.color = '#000';
      }
      function formSubmit() {
        domain = document.getElementById('numero_input').value;
        window.location = '/' + domain;
        return false;
      }
    %title
      Qual é a operadora?

  %body
    #container
      = yield

@@ index
%form{:onsubmit => "return formSubmit()"}
  Qual a operadora de
  %input{:type => 'text', :name => 'numero', :id => 'numero_input', :onclick => "clearInput(this)", :value => '8888888888'}
  %a{:href => "#", :onclick => "formSubmit();"}
    ?

@@ operadora
%p
  %img{:src => @logotipo, :alt => @operadora}
%p
  A operadora de
  %em
    = @numero
  é
  %em
    = @operadora + "."
%p
  %a{:href => "/"}
    Quer ver outro número?
