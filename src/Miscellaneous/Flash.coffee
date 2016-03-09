Flash =
  init: ->
    if g.BOARD.ID is 'f'
      $.ready Flash.initReady

  initReady: ->
    $.globalEval 'SWFEmbed.init()'

    return unless g.VIEW is 'thread'

    # Flash Replies
    res = $.ajax "//a.4cdn.org/#{g.BOARD.ID}/thread/#{g.THREADID}.json",
      onloadend: ->
        for post in res.response.posts
          if post.filename and post.no isnt g.THREADID
            temp = "#pi#{post.no}"
            file = $.el 'a',
              "data-width":   "#{post.w}"
              "data-height":  "#{post.h}"
              href:           "//i.4cdn.org/#{g.BOARD.ID}/#{encodeURIComponent post.filename}#{post.ext}"
              target:         "_blank"
              textContent:    "#{post.filename}"
            fileDiv = $.el 'div'
            $.addClass fileDiv, "fileInfo"
            fileSpan = $.el 'span',
              id:             "fT#{post.no}"
            $.addClass fileSpan, "fileText"
            $.add fileSpan, [$.tn("File: "), file, $.tn("-(#{$.bytesToString(post.fsize)}, #{post.w}x#{post.h})")]
            $.add fileDiv, fileSpan
            $.after $(temp), fileDiv
        # Sauce
        swfName = $$ '.fileText > a'
        for file in swfName
          if file.href != "javascript:;"
            sauceLink = $.el 'a',
              id:          'sauceSWF'
              textContent: 'swfchan'
              href:        "//eye.swfchan.com/search/?q=#{file.textContent}"
              target:      "_blank"
            $.add file.parentNode.parentNode, [$.tn(' '),sauceLink]