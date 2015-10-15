Captcha.v2 = class extends Captcha
  constructor: ->
  shouldFocus: false
  timeouts: {}
  postsCount: 0

  impInit: ->
    root = $.el 'div', className: 'captcha-root'
    $.extend root, <%= html(
      '<div class="captcha-counter"><a href="javascript:;"></a></div>'
    ) %>
    counter   = $ '.captcha-counter > a', root
    @nodes = {root, counter}
    @count()
    $.addClass QR.nodes.el, 'has-captcha', 'captcha-v2'
    $.after QR.nodes.com.parentNode, root

    $.on counter, 'click', @toggle.bind @
    $.on counter, 'keydown', (e) =>
      return unless Keybinds.keyCode(e) is 'Space'
      @toggle()
      e.preventDefault()
      e.stopPropagation()
    $.on window, 'captcha:success', =>
      # XXX Greasemonkey 1.x workaround to gain access to GM_* functions.
      $.queueTask => @save false

  initFrame: ->
    if token = $('.fbc-verification-token > textarea')?.value
      conn = new Connection window.parent, "#{location.protocol}//boards.4chan.org"
      conn.send {token}

  impSetup: (focus, force) ->
    @shouldFocus = true if focus and not QR.inBubble()
    if @timeouts.destroy
      clearTimeout @timeouts.destroy
      delete @timeouts.destroy
      return @reload()

    if @nodes.container
      if @shouldFocus and iframe = $ 'iframe', @nodes.container
        iframe.focus()
        QR.focus() # Event handler not fired in Firefox
        delete @shouldFocus
      return

    @nodes.container = $.el 'div', className: 'captcha-container'
    $.prepend @nodes.root, @nodes.container
    new MutationObserver(@postSetup.bind @).observe @nodes.container,
      childList: true
      subtree: true

    @setupJS()

  setupJS: ->
    $.globalEval """
      (function() {
        function render() {
          var container = document.querySelector("#qr .captcha-container");
          container.dataset.widgetID = window.grecaptcha.render(container, {
            sitekey: '<%= meta.recaptchaKey %>',
            theme: #{if Style.lightTheme then "'light'" else "'dark'"},
            callback: function(response) {
              window.dispatchEvent(new CustomEvent("captcha:success", {detail: response}));
            }
          });
        }
        if (window.grecaptcha) {
          render();
        } else {
          var cbNative = window.onRecaptchaLoaded;
          window.onRecaptchaLoaded = function() {
            render();
            cbNative();
          }
        }
      })();
    """

  postSetup: (mutations) ->
    for mutation in mutations
      for node in mutation.addedNodes
        @setupIFrame   iframe   if iframe   = $.x './descendant-or-self::iframe',   node
        @setupTextArea textarea if textarea = $.x './descendant-or-self::textarea', node
    return

  setupIFrame: (iframe) ->
    Captcha.replace.iframe iframe
    $.addClass QR.nodes.el, 'captcha-open'
    if QR.nodes.el.getBoundingClientRect().bottom > doc.clientHeight
      QR.nodes.el.style.top    = null
      QR.nodes.el.style.bottom = '0px'
    iframe.focus() if @shouldFocus
    @shouldFocus = false

  setupTextArea: (textarea) ->
    $.one textarea, 'input', => @save true

  onNewPost: ->
    @setup()

  onPostChange: ->
    @setup() if @postsCount is 0
    @postsCount = 0 if QR.posts.length is 1 and !Conf['Auto-load captcha'] and !QR.posts[0].com and !QR.posts[0].file

  toggle: ->
    if @nodes.container and !@timeouts.destroy
      @destroy()
    else
      @setup true, true

  destroy: ->
    return unless @isEnabled
    delete @timeouts.destroy
    $.rmClass QR.nodes.el, 'captcha-open'
    $.rm @nodes.container if @nodes.container
    delete @nodes.container
    # Clean up abandoned iframes.
    for garbage in $$ 'div > .gc-bubbleDefault'
      $.rm ins if (ins = garbage.parentNode.nextSibling) and ins.nodeName is 'INS'
      $.rm garbage.parentNode
    return

  save: (pasted, token) ->
    $.forceSync 'captchas'
    @captchas.push
      response: token or $('textarea', @nodes.container).value
      timeout:  Date.now() + @lifetime
    $.set 'captchas', @captchas
    @count()

    focus = d.activeElement?.nodeName is 'IFRAME' and /https?:\/\/www\.google\.com\/recaptcha\//.test(d.activeElement.src)
    if @needed()
      if focus
        if QR.cooldown.auto or Conf['Post on Captcha Completion']
          @shouldFocus = true
        else
          QR.nodes.status.focus()
      @reload()
    else
      if pasted
        @destroy()
      else
        @timeouts.destroy ?= setTimeout @destroy.bind(@), 3 * $.SECOND
      QR.nodes.status.focus() if focus

    QR.submit() if Conf['Post on Captcha Completion'] and !QR.cooldown.auto

  clear: ->
    @setup(d.activeElement is QR.nodes.status) if super()

  count: ->
    @nodes.counter.textContent = "Captchas: #{@captchas.length}"
    clearTimeout @timeouts.clear
    if @captchas.length
      @timeouts.clear = setTimeout @clear.bind(@), @captchas[0].timeout - Date.now()

  reload: ->
    $.globalEval '''
      (function() {
        var container = document.querySelector("#qr .captcha-container");
        window.grecaptcha.reset(container.dataset.widgetID);
      })();
    '''
