Captcha.noscript = class extends Captcha
  constructor: ->
    @cb =
      focus: Captcha::cb.focus
      load:  (-> if @nodes.iframe then @reload() else @setup()).bind @
      cache: (-> @sendResponse()).bind @

  iframeURL: '//www.google.com/recaptcha/api/noscript?k=<%= meta.recaptchaKey %>'
  lifetime: 30 * $.MINUTE
  timers: {}

  impInit: ->
    @buildV1Nodes()

    $.addClass QR.nodes.el, 'noscript-captcha'

    @conn = new Connection null, "#{location.protocol}//www.google.com",
      challenge: @load.bind @
      token:     @save.bind @
      error:     @error.bind @

    @preSetup()
    @setup()

  initFrame: ->
    conn = new Connection window.parent, "#{location.protocol}//boards.4chan.org",
      response: (response) ->
        $.id('recaptcha_response_field').value = response
        # The form has a field named 'submit'
        HTMLFormElement.prototype.submit.call $('form')
    if location.hash is '#response'
      conn.send
        token: $('textarea')?.value
        error: $('.recaptcha_input_area')?.textContent.replace(/:$/, '')
    return unless img = $ 'img'
    $('form').action = '#response'
    cb = ->
      canvas = $.el 'canvas'
      canvas.width  = img.width
      canvas.height = img.height
      canvas.getContext('2d').drawImage(img, 0, 0)
      conn.send {challenge: canvas.toDataURL()}
    if img.complete
      cb()
    else
      $.on img, 'load', cb

  preSetup: ->
    {container, input} = @nodes
    container.hidden = true
    input.value = ''
    input.placeholder = 'Focus to load reCAPTCHA'
    @count()
    $.on input, 'focus click', @cb.focus

  impSetup: (focus, force) ->
    @create()
    @nodes.input.focus() if focus

  create: ->
    if !@nodes.iframe
      @nodes.iframe = $.el 'iframe',
        id: 'qr-captcha-iframe'
        src: @iframeURL
      $.add QR.nodes.el, @nodes.iframe
      @conn.target = @nodes.iframe
    else if !@occupied or force
      @nodes.iframe.src = @iframeURL
    @occupied = true

  postSetup: ->
    {container, input} = @nodes
    container.hidden = false
    input.placeholder = 'Verification'
    @count()
    $.off input, 'focus click', @cb.focus

    if QR.nodes.el.getBoundingClientRect().bottom > doc.clientHeight
      QR.nodes.el.style.top    = ''
      QR.nodes.el.style.bottom = '0px'

  destroy: ->
    return unless @isEnabled
    $.rm @nodes.img
    delete @nodes.img
    $.rm @nodes.iframe
    delete @nodes.iframe
    delete @occupied
    @preSetup()

  # handleCaptcha: -> super()

  handleNoCaptcha: ->
    if /\S/.test @nodes.input.value
      (cb) =>
        @submitCB = cb
        @sendResponse()
    else
      null

  sendResponse: ->
    response = @nodes.input.value
    if /\S/.test response
      @conn.send {response}

  save: (token) ->
    delete @occupied
    @nodes.input.value = ''
    captcha =
      challenge: token
      response:  'manual_challenge'
      timeout:   @timeout
    if @submitCB
      @submitCB captcha
      delete @submitCB
      if @needed() then @reload() else @destroy()
    else
      $.forceSync 'captchas'
      @captchas.push captcha
      @count()
      $.set 'captchas', @captchas
      @reload()

  load: (src) ->
    {container, input, img} = @nodes
    @occupied = true
    @timeout = Date.now() + @lifetime
    unless img
      img = @nodes.img = new Image()
      $.one img, 'load', @postSetup.bind @
      $.on img, 'load', -> @hidden = false
      $.add container, img
    img.src = src
    input.value = ''
    @clear()
    clearTimeout @timers.expire
    @timers.expire = setTimeout @expire.bind(@), @lifetime

  reload: ->
    @nodes.iframe.src = @iframeURL
    @occupied = true
    @nodes.img?.hidden = true

  count: ->
    super()
    clearTimeout @timers.clear
    if @captchas.length
      @timers.clear = setTimeout @clear.bind(@), @captchas[0].timeout - Date.now()

  error: (message) ->
    @occupied = true
    @nodes.input.value = ''
    if @submitCB
      @submitCB()
      delete @submitCB
    QR.error "Captcha Error: #{message}"

  expire: ->
    return unless @nodes.iframe
    if not d.hidden and (@needed() or d.activeElement is @nodes.input)
      @reload()
    else
      @destroy()
