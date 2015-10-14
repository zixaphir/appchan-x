Captcha.v1 = class extends Captcha
  constructor: ->
    @cb =
      focus: Captcha::cb.focus
      load:  @reload.bind @
      cache: @save.bind @

  blank = "data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' width='300' height='57'/>"

  impInit: ->
    @buildV1Nodes()

    @nodes.img = img = $.el 'img'
    $.add @nodes.container, img

    @replace()
    @preSetup()
    @setup() if Conf['Auto-load captcha']

    new MutationObserver(@postSetup).observe $('#g-recaptcha, #captchaContainerAlt'), childList: true
    @postSetup() # reCAPTCHA might have loaded before the QR.

  preSetup: ->
    {container, img} = @nodes
    container.hidden = true
    container.src = @blank
    super()

  impSetup: (focus, force) ->
    @create()
    @reload focus

  postSetup: ->
    return unless challenge = $.id 'recaptcha_challenge_field_holder'
    return if challenge is QR.captcha.nodes.challenge

    setLifetime = (e) -> QR.captcha.lifetime = e.detail
    $.on window, 'captcha:timeout', setLifetime
    $.globalEval 'window.dispatchEvent(new CustomEvent("captcha:timeout", {detail: RecaptchaState.timeout}))'
    $.off window, 'captcha:timeout', setLifetime

    {container, input} = QR.captcha.nodes
    container.hidden = false
    input.placeholder = 'Verification'
    QR.captcha.count()
    $.off input, 'focus click', QR.captcha.cb.focus

    QR.captcha.nodes.challenge = challenge
    new MutationObserver(QR.captcha.load.bind QR.captcha).observe challenge,
      childList: true
      subtree: true
      attributes: true
    QR.captcha.load()

    if QR.nodes.el.getBoundingClientRect().bottom > doc.clientHeight
      QR.nodes.el.style.top    = null
      QR.nodes.el.style.bottom = '0px'

  replace: ->
    return if @script
    unless @script = $ 'script[src="//www.google.com/recaptcha/api/js/recaptcha_ajax.js"]', d.head
      @script = $.el 'script',
        src: '//www.google.com/recaptcha/api/js/recaptcha_ajax.js'
      $.add d.head, @script
    if old = $.id 'g-recaptcha'
      container = $.el 'div',
        id: 'captchaContainerAlt'
      $.replace old, container

  # handleCaptcha: (captcha) -> super captcha

  handleNoCaptcha: ->
    challenge = @nodes.img.alt
    timeout   = @timeout
    if /\S/.test(response = @nodes.input.value)
      @destroy()
      {challenge, response, timeout}
    else
      null

  create: ->
    $.globalEval '''
      (function() {
        var container = document.getElementById("captchaContainerAlt");
        if (container.firstChild) return;
        var options = {
          theme: "clean",
          tabindex: {"boards.4chan.org": 5, "sys.4chan.org": 3}[location.hostname]
        };
        if (window.Recaptcha) {
          window.Recaptcha.create("<%= meta.recaptchaKey %>", container, options);
        } else {
          var script = document.head.querySelector('script[src="//www.google.com/recaptcha/api/js/recaptcha_ajax.js"]');
          script.addEventListener('load', function() {
            window.Recaptcha.create("<%= meta.recaptchaKey %>", container, options);
          }, false);
        }
      })();
    '''

  save: ->
    return unless /\S/.test(response = @nodes.input.value)
    @nodes.input.value = ''
    @captchas.push
      challenge: @nodes.img.alt
      response:  response
      timeout:   @timeout
    @count()
    @destroy()
    @setup false, true
    $.set 'captchas', @captchas

  load: ->
    if $('#captchaContainerAlt[class~="recaptcha_is_showing_audio"]')
      @nodes.img.src = @blank
      return
    return unless @nodes.challenge.firstChild
    return unless challenge_image = $.id 'recaptcha_challenge_image'
    # -1 minute to give upload some time.
    @timeout  = Date.now() + @lifetime * $.SECOND - $.MINUTE
    challenge = @nodes.challenge.firstChild.value
    @nodes.img.alt = challenge
    @nodes.img.src = challenge_image.src
    @nodes.input.value = ''
    @clear()

  reload: (focus) ->
    # Recaptcha.should_focus = false: Hack to prevent the input from being focused
    $.globalEval '''
      if (window.Recaptcha.type === "image") {
        window.Recaptcha.reload();
      } else {
        window.Recaptcha.switch_type("image");
      }
      window.Recaptcha.should_focus = false;
    '''
    @nodes.input.focus() if focus

  # clear: -> super()

  destroy: ->
    return unless @script
    $.globalEval 'window.Recaptcha.destroy();'
    @beforeSetup() if @nodes
