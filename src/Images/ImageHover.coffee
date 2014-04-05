ImageHover =
  init: ->
    return if g.VIEW is 'catalog' or !Conf['Image Hover']

    Post.callbacks.push
      name: 'Image Hover'
      cb:   @node
  node: ->
    return unless @file and (@file.isImage or @file.isVideo)
    $.on @file.thumb, 'mouseover', ImageHover.mouseover
  mouseover: (e) ->
    post = Get.postFromNode @
    el = if post.file.isImage
      $.el 'img',
        id: 'ihover'
        src: post.file.URL
    else
      $.el 'video',
        id: 'ihover'
        src: post.file.URL
        autoplay: true
        loop: true
    el.dataset.fullID = post.fullID
    $.add Header.hover, el
    UI.hover
      root: @
      el: el
      latestEvent: e
      endEvents: 'mouseout click'
      asapTest: -> post.file.isVideo or el.naturalHeight
    $.on el, 'error', ImageHover.error
  error: ->
    return unless doc.contains @
    post = g.posts[@dataset.fullID]

    src = @src.split '/'
    if src[2] is 'i.4cdn.org'
      URL = Redirect.to 'file',
        boardID:  src[3]
        filename: src[5].replace /\?.+$/, ''
      if URL
        @src = URL
        return
      if g.DEAD or post.isDead or post.file.isDead
        return

    timeoutID = setTimeout (=> @src = post.file.URL + '?' + Date.now()), 3000
    # XXX CORS for i.4cdn.org WHEN?
    $.ajax "//a.4cdn.org/#{post.board}/res/#{post.thread}.json", onload: ->
      return if @status isnt 200
      for postObj in JSON.parse(@response).posts
        break if postObj.no is post.ID
      if postObj.no isnt post.ID
        clearTimeout timeoutID
        post.kill()
      else if postObj.filedeleted
        clearTimeout timeoutID
        post.kill true
