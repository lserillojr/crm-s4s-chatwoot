# frozen_string_literal: true

# Modo embed S4S (Portal Único) — gated por ?embed=s4s.
#
# Quando o Portal carrega o Chatwoot num iframe, ele aponta pra
# <host>/<path>?embed=s4s. Este middleware Rack faz 3 coisas numa passada:
#
#   1) COOKIE: ao ver embed=s4s na query, seta s4s_embed=1 (sessão). O cookie
#      faz o modo embed SOBREVIVER aos redirects internos do Chatwoot que perdem
#      a query string (ex.: login -> dashboard). SameSite=Lax basta porque o
#      Portal e o Chatwoot são subdomínios do MESMO site registrável
#      (staff4solutions.com.br) — iframe same-site manda o cookie. NÃO é HttpOnly:
#      o snippet de <head> precisa lê-lo via JS pra marcar a classe antes do paint.
#
#   2) CHROME-OFF: injeta no <head> de respostas text/html um <script> que marca
#      <html class="s4s-embed"> a partir do cookie + um <link> pro CSS que esconde
#      sidebar/topbar. Optamos por injeção via middleware (e NÃO por editar o
#      layout nativo vueapp.html.erb) pra não depender do conteúdo exato do layout
#      da versão — resiliente a upgrades do Chatwoot e fiel ao padrão "patch isolado"
#      dos demais arquivos deste repo. O CSS é o único lugar onde os seletores de
#      chrome vivem (ver public/embed_s4s.css), marcados como SPIKE a confirmar.
#
#   3) FRAME-ANCESTORS: se S4S_PORTAL_ORIGIN estiver setada, remove X-Frame-Options
#      e adiciona frame-ancestors liberando o Portal como pai do iframe (senão o
#      iframe fica branco silenciosamente). Sem a env, nada muda (seguro por padrão).
#
# Observação de SPIKE: este middleware reescreve o corpo de respostas HTML pra
# injetar o snippet. Só age quando Content-Type é text/html E não há
# Content-Encoding (corpo ainda não comprimido — compressão é do proxy, downstream).

class S4sEmbedMiddleware
  # Snippet injetado antes de </head>. O <script> roda síncrono (antes do paint)
  # e marca a classe a partir do cookie; o <link> render-blocking aplica o CSS.
  #
  # O script também NEUTRALIZA o título da aba: a stack de base é invisível ao MEI,
  # mas o Chatwoot grava "… - Chatwoot" em document.title. Quando o MEI abre o
  # atendimento numa aba standalone (atalho SSO do onboarding), esse título VAZA na
  # aba do navegador. Removemos "Chatwoot" do título e seguimos as trocas que a SPA
  # Vue faz ao navegar (MutationObserver no <title>, com guarda anti-loop). Fallback
  # "Meu atendimento".
  HEAD_SNIPPET =
    '<script>if(document.cookie.indexOf("s4s_embed=1")>-1){' \
    'document.documentElement.classList.add("s4s-embed");' \
    '(function(){function c(){var t=document.title||"";' \
    'var n=t.replace(/\s*[-|]\s*Chatwoot\b/gi,"").replace(/^\s*Chatwoot\b\s*[-|]?\s*/i,"")' \
    '.replace(/\s{2,}/g," ").trim();if(!n){n="Meu atendimento"}' \
    'if(n!==t){document.title=n}}function w(){c();var e=document.querySelector("title");' \
    'if(e&&window.MutationObserver){new MutationObserver(c).observe(e,{childList:true})}}' \
    'if(document.querySelector("title")){w()}else{document.addEventListener("DOMContentLoaded",w)}' \
    '})()}</script>' \
    '<link rel="stylesheet" href="/embed_s4s.css">'

  def initialize(app)
    @app = app
  end

  def call(env)
    # Só a query — não tocar no corpo do request (parse de params POST faria rewind).
    embed = Rack::Utils.parse_query(env['QUERY_STRING'])['embed'] == 's4s'

    status, headers, body = @app.call(env)

    set_embed_cookie(headers) if embed
    allow_portal_frame_ancestors(headers)
    body = inject_head_snippet(headers, body)

    [status, headers, body]
  end

  private

  def set_embed_cookie(headers)
    # Sessão (sem expiração), escopo do host, legível por JS, same-site Lax.
    Rack::Utils.set_cookie_header!(
      headers, 's4s_embed',
      value: '1', path: '/', same_site: :lax, secure: true, http_only: false
    )
  end

  def allow_portal_frame_ancestors(headers)
    portal = ENV['S4S_PORTAL_ORIGIN'].to_s.strip
    return if portal.empty?

    headers.delete('X-Frame-Options')
    ancestors = "frame-ancestors 'self' #{portal}"
    existing = headers['Content-Security-Policy']
    headers['Content-Security-Policy'] =
      existing && !existing.empty? ? "#{existing}; #{ancestors}" : ancestors
  end

  def inject_head_snippet(headers, body)
    return body unless html_response?(headers)

    html = +''
    body.each { |part| html << part.to_s }
    body.close if body.respond_to?(:close)

    return [html] unless html.include?('</head>')

    html = html.sub('</head>', "#{HEAD_SNIPPET}</head>")
    headers['Content-Length'] = html.bytesize.to_s if headers.key?('Content-Length')
    [html]
  end

  def html_response?(headers)
    ct = headers['Content-Type'].to_s
    ct.include?('text/html') && headers['Content-Encoding'].to_s.empty?
  end
end

Rails.application.config.middleware.use(S4sEmbedMiddleware)
