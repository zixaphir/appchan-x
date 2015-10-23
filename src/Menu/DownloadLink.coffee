DownloadLink =
  init: ->
    return unless g.VIEW in ['index', 'thread']

    if Conf['Add Download Attribute to Filename']
      Post.callbacks.push
        name: 'DownloadLink'
        cb:   @node

    return unless Conf['Menu'] and Conf['Download Link']

    a = $.el 'a',
      className: 'download-link'
      textContent: 'Download file'

    # Specifying the filename with the download attribute only works for same-origin links.
    $.on a, 'click', ImageCommon.download

    Menu.menu.addEntry
      el: a
      order: 100
      open: ({file}) ->
        return false unless file
        a.href     = file.URL
        a.download = file.name
        true

  node: ->
    return unless @file
    # Filename formatting really fucks with this.
    a = $('.file-info a', @file.text) or @file.text.firstElementChild
    console.log a
    a.download = @file.name