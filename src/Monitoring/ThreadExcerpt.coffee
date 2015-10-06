ThreadExcerpt =
  init: ->
    return if g.VIEW isnt 'thread'

    Thread.callbacks.push
      name: 'Thread Excerpt'
      cb:   @node
  node: -> d.title = Get.threadExcerpt @
  disconnect: ->
    return if g.VIEW isnt 'thread'
    Thread.callbacks.disconnect 'Thread Excerpt'
