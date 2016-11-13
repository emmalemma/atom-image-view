fs = require 'fs-plus'
{$, ScrollView} = require 'atom-space-pen-views'
{Emitter, CompositeDisposable} = require 'atom'

# View that renders the image of an {ImageEditor}.
module.exports =
class ImageEditorView extends ScrollView
  @content: ->
    @div class: 'image-view', tabindex: -1, =>
      @div class: 'image-controls', outlet: 'imageControls', =>
        @div class: 'image-controls-group', =>
          @select outlet: 'backgroundColorSelect', class: 'input-select', =>
            @option 'background', value: ''
            @option 'White', value: 'white'
            @option 'Black', value: 'black'
            @option 'Transparent', value: 'transparent'
            @option 'Chess (light)', value: 'chess-light'
            @option 'Chess (dark)', value: 'chess-dark'
        @div class: 'image-controls-group btn-group', =>
          @button class: 'btn', outlet: 'zoomOutButton', '-'
          @button class: 'btn reset-zoom-button', outlet: 'resetZoomButton', '100%'
          @button class: 'btn', outlet: 'zoomInButton', '+'
        @div class: 'image-controls-group btn-group', =>
          @button class: 'btn', outlet: 'zoomToFitButton', 'Zoom to fit'

      @div class: 'image-container', background: 'white', outlet: 'imageContainer', =>
        @img outlet: 'image'

  initialize: (@editor) ->
    super
    @emitter = new Emitter
    @imageSize = fs.statSync(@editor.getPath())["size"]

  attached: ->
    @disposables = new CompositeDisposable

    @loaded = false
    @loadedTime = 0
    @mode = 'reset-zoom'
    @image.hide()
    @updateImageURI()

    @disposables.add @editor.onDidChange => @updateImageURI()
    @disposables.add atom.commands.add @element,
      'image-view:reload': => @updateImageURI()
      'image-view:zoom-in': => @zoomIn()
      'image-view:zoom-out': => @zoomOut()
      'image-view:zoom-to-fit': => @zoomToFit()
      'image-view:reset-zoom': => @resetZoom()

    @image.load =>
      @originalHeight = @image.prop('naturalHeight')
      @originalWidth = @image.prop('naturalWidth')
      @loaded = true
      @image.show()
      @emitter.emit 'did-load'

    if @getPane()
      @backgroundColorSelect.on 'change', (e) =>
        @changeBackground e.target.value
        e.target.value = ''

    @zoomInButton.on 'click', => @zoomIn()
    @zoomOutButton.on 'click', => @zoomOut()
    @resetZoomButton.on 'click', => @resetZoom()
    @zoomToFitButton.on 'click', => @zoomToFit()

  onDidLoad: (callback) ->
    @emitter.on 'did-load', callback

  detached: ->
    @disposables.dispose()

  updateImageURI: ->
    timestamp = Date.now()
    buffer = new Image()
    buffer.src = "#{@editor.getEncodedURI()}?time=#{timestamp}"
    buffer.onload =()=>
      if @loadedTime < timestamp
        @loadedTime = timestamp
        @image.attr('src', buffer.src)

  # Retrieves this view's pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parents('.pane')[0]

  # Zooms the image out by 25%.
  zoomOut: ->
    @adjustSize(0.75)

  # Zooms the image in by 25%.
  zoomIn: ->
    @adjustSize(1.25)

  # Zooms the image to its normal width and height.
  resetZoom: ->
    return unless @loaded and @isVisible()

    @mode = 'reset-zoom'
    @imageContainer.removeClass 'zoom-to-fit'
    @zoomToFitButton.removeClass 'selected'
    @image.width(@originalWidth)
    @image.height(@originalHeight)
    @resetZoomButton.text('100%')

  # Zooms to fit the image, doesn't scale beyond actual size
  zoomToFit: ->
    return unless @loaded and @isVisible()

    @mode = 'zoom-to-fit'
    @imageContainer.addClass 'zoom-to-fit'
    @zoomToFitButton.addClass 'selected'
    @image.width('')
    @image.height('')
    @resetZoomButton.text('Auto')

  # Adjust the size of the image by the given multiplying factor.
  #
  # factor - A {Number} to multiply against the current size.
  adjustSize: (factor) ->
    return unless @loaded and @isVisible()

    if @mode is 'zoom-to-fit'
      @mode = 'zoom-manual'
      @imageContainer.removeClass 'zoom-to-fit'
      @zoomToFitButton.removeClass 'selected'
    else if @mode is 'reset-zoom'
      @mode = 'zoom-manual'

    newWidth = @image.width() * factor
    newHeight = @image.height() * factor
    percent = Math.max(1, Math.round(newWidth/@originalWidth*100))

    # Switch to pixelated rendering when image is bigger than 200%
    if newWidth > @originalWidth*2
      @image.css 'image-rendering', 'pixelated'
    else
      @image.css 'image-rendering', ''

    @image.width(newWidth)
    @image.height(newHeight)
    @resetZoomButton.text(percent + '%')

  # Changes the background color of the image view.
  #
  # color - A {String} that gets used as class name.
  changeBackground: (color) ->
    return unless @loaded and @isVisible() and color
    @imageContainer.attr('background', color)
