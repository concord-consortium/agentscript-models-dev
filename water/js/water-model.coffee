class WaterModel extends ABM.Model
  DOWN:  ABM.util.degToRad(270)
  LEFT:  ABM.util.degToRad(180)
  UP:    ABM.util.degToRad(90)
  CONE:  ABM.util.degToRad(110)
  RIGHT: 0

  template: null
  templateData: { url: null, data: null }

  ticksPerYear: 732
  ticksPerMonth: 61

  evapProbability: 10
  rainProbability: 0.33
  sprayIntensity: 10

  wells: null
  wellLimit: 5
  drillSpeed: 2
  killed: 0
  newWellType: null

  _toRedraw: null
  _toKill: null
  _toDoAtEnd: null
  _tileControl: null

  _soilTileLoaded: false
  _rock1TileLoaded: false
  _rock2TileLoaded: false
  _rock3TileLoaded: false
  _rock4TileLoaded: false

  _setupComplete: false

  @MONTH_ELAPSED: "modelMonthElapsed"
  @YEAR_ELAPSED:  "modelYearElapsed"

  constructor: ->
    super
    @_tileControl = new TileControl @
    @_tileControl.addTile "soil", 'img/tile_soil_01.png', =>
      @_soilTileLoaded = true
      @_notifyIfLoaded()
    @_tileControl.addTile "rock1", 'img/tile_sand_01.png', =>
      @_rock1TileLoaded = true
      @_notifyIfLoaded()
    @_tileControl.addTile "rock2", 'img/tile_clay_01.png', =>
      @_rock2TileLoaded = true
      @_notifyIfLoaded()
    @_tileControl.addTile "rock3", 'img/tile_gravel_01.png', =>
      @_rock3TileLoaded = true
      @_notifyIfLoaded()
    @_tileControl.addTile "rock4", 'img/tile_bedrock_01.png', =>
      @_rock4TileLoaded = true
      @_notifyIfLoaded()

  _notifyIfLoaded: ->
    if @_soilTileLoaded and @_rock1TileLoaded and @_rock2TileLoaded and @_rock3TileLoaded and @_rock4TileLoaded and @_setupComplete
      $(document).trigger('model-ready')

  setup: ->
    @_toRedraw = []
    @_toKill = []
    @_toDoAtEnd = []
    @wells = []
    @newWellType = WaterRemovalWell

    @ticksPerMonth = @ticksPerYear / 12

    @anim.setRate 30, false
    @setFastPatches()

    @setTextParams {name: "drawing"}, "10px sans-serif"
    @setLabelParams {name: "drawing"}, [255,255,255], [0,-20]

    # init all the patches as sky color
    # unless we have a template to load
    if @template? and @template isnt ""
      loadData = (data)=>
        ImportExport.import(@, data)
      if @templateData[@template]?
        loadData(@templateData[@template])
      else
        # load in the defined template json
        $.getJSON(@template, (data)=>
          @templateData[@template] = data
          loadData(data)
        ).fail =>
          @_clear()
    else
     @_clear()

    @setCacheAgentsHere()

    @agentBreeds "rain wellWater evap spray"

    @setupRain()
    @setupEvap()
    @setupWellWater()
    @setupSpray()

    @draw()
    @refreshPatches = false

    @spotlightRadius = 12

    @_setupComplete = true
    @_notifyIfLoaded()

  _clear: ->
    for p in @patches
      p.color = [205, 237, 252]
      p.type = "sky"

  redraw: ->
    redrawSet = ABM.util.clone @_toRedraw
    @_toRedraw = []
    setTimeout =>
      @patches.drawScaledPixels @contexts.patches, redrawSet
    , 1

  patchChanged: (p, redraw=true)->
    unless p.isWell
      p.color = @_tileControl.lookupColor p
    @_toRedraw.push p if redraw

  reset: ->
    super
    @setup()
    @anim.draw()

  start: ->
    super
    for p in @patches
      p.isOnSurface = @isOnSurface(p)
      p.isOnAirSurface = @isOnAirSurface(p)

  step: ->
    console.log @anim.toString() if @anim.ticks % 100 is 0

    @createRain()

    for r in @rain
      @moveFallingWater(r)

    for e in @evap
      @moveEvaporation(e)

    for w in @wellWater
      @moveWellWater(w)

    for s in @spray
      @moveSpray(s)

    @suckUpWellWater()
    @evaporateWater()

    for f in @_toDoAtEnd
      f.apply(this, null)
    @_toDoAtEnd = []

    for a in @_toKill
      a.die()
      if a.well
        @killed++
        a.well.killed++
        a.well.totalKilled++
    @_toKill = []

    if @anim.ticks % @ticksPerMonth is 0
      $(document).trigger @constructor.MONTH_ELAPSED

    if @anim.ticks % @ticksPerYear is 0
      $(document).trigger @constructor.YEAR_ELAPSED

    return true # avoid inadventently returning a large array of things

  _setupWater: (agents)->
    agents.setDefaultSize 2/@world.size  # try to keep water around 2px in size
    agents.setDefaultColor [0, 0, 255, 0.4]
    agents.setDefaultShape "circle"

  setupRain: ->
    @_setupWater @rain
    @rain.setDefaultHeading @DOWN

  setupEvap: ->
    @_setupWater @evap
    @evap.setDefaultColor [0, 255, 0]
    @evap.setDefaultHeading @UP

  setupWellWater: ->
    @_setupWater @wellWater
    @wellWater.setDefaultHeading @UP

  setupSpray: ->
    @spray.setDefaultHeading @UP
    @_setupWater @spray

  createRain: ->
    # too many agents will make it really slow
    if (@anim.ticks % @ticksPerYear) < (@rainProbability * @ticksPerYear)
      @rain.create 5, (a)=>
        p = null
        while not @isPatchFree(p)
          px = @random(@patches.maxX - @patches.minX) + @patches.minX
          p = @patches.patchXY px, @patches.maxY
        a.moveTo p

  isOnSurface: (p)->
    # The first patch of a layer is the "surface".
    # We are the surface if the patch immediately above or diagonally above isn't the same type.
    # However, don't use surface dynamics if we're under an impermeable layer (rock4).
    isSurface = (p.type isnt p.n[6]?.type and p.n[6]?.type isnt "rock4") or
           (p.type isnt p.n[5]?.type and p.n4[5]?.type isnt "rock4") or
           (p.type isnt p.n[7]?.type and p.n4[7]?.type isnt "rock4")

    return isSurface

  isOnAirSurface: (p)->
    # Patches with an air patch directly or diagonally above is on the "air surface".
    # This is used to decide whether water is eligible for evaporation
    isFirstRockLayer = p.type isnt "sky" and
                (p.n[5]?.type is "sky" or
                 p.n[6]?.type is "sky" or
                 p.n[7]?.type is "sky")
    isLastSkyLayer = p.type is "sky" and
                (p.n[0]?.type isnt "sky" or
                 p.n[1]?.type isnt "sky" or
                 p.n[2]?.type isnt "sky")

    return isFirstRockLayer or isLastSkyLayer

  getNextPatch: (a)->
    dir = Math.round(ABM.util.radToDeg(a.heading))
    return switch dir
      when 0   then a.p.n4[2]
      when 90  then a.p.n4[3]
      when 180 then a.p.n4[1]
      when 270 then a.p.n4[0]
      else a.p.n4[0]

  isPatchFree: (p)->
    return p? and p.agentsHere().length == 0

  resistance: (p)->
    # 1/resistance is the prob of moving, it is like a resistance to flow.
    # If the patch is the top patch of a layer, resist water flow more than usual to
    # encourage travel along layer surfaces.
    return switch p.type
      when "soil"  then (if p.isOnSurface then  32 else   4)
      when "rock1" then (if p.isOnSurface then  64 else   8)
      when "rock2" then (if p.isOnSurface then 128 else  16)
      when "rock3" then (if p.isOnSurface then 256 else  32)
      when "rock4" then 1000000
      else 1

  random: (n)->
    return Math.floor(Math.random()*n)

  findNearbyWell: (p)->
    if p.isWell
      return p.well
    else
      # look within an N patch radius of us for a well patch
      near = @patches.patchRect p, 5, 10, true
      for pn in near
        if pn.isWell
          return pn.well
    return null

  drill: (p)->
    # drill at the specified patch
    well = @findNearbyWell(p)
    if well?
      well.drill "down", @drillSpeed
      @redraw()
    else if p.x > (@patches.minX + 3) and p.x < (@patches.maxX - 5)
      return if @wells.length >= @wellLimit
      for w in @wells
        return if (0 < Math.abs(p.x - w.head.x) < 10)
      wellHeadY = null
      # debugger
      if p.type isnt "sky"
        # search up to 10 patches above this for a patch that is sky
        i = 0; possPatch = p
        while possPatch.type isnt "sky" and i < 11
          possPatch = possPatch.n4[3]
          i++
        if possPatch.type is "sky"
          wellHeadY = possPatch.y
      else
        # search up to 10 patches below this for a patch that isn't sky
        i = 0; possPatch = p
        while possPatch.type is "sky" and i < 11
          possPatch = possPatch.n4[0]
          i++
        if possPatch.type isnt "sky"
          wellHeadY = possPatch.n4[3].y
      if wellHeadY?
        well = new @newWellType @, p.x, wellHeadY
        @wells.push well
        # start a new vertical well as long as we're not too close to the wall
        for y in [(wellHeadY-1)..(p.y)]
          well.drillVertical()
        @redraw()

  moveFallingWater: (a)->
    ps = []
    resistanceModifier = 1
    for i in [{ idx: 1, priority: 0 }, { idx: 0, priority: 1}, { idx: 2, priority: 1}, { idx: 3, priority: 2}, {idx: 4, priority: 2}]
      i.patch = a.p.n[i.idx]
      continue unless i.patch?
      continue unless @isPatchFree(i.patch)

      preferred = false
      i.priority += 1 unless i.patch.type is "sky"
      # if the patch to the right is occupied, bump up either of the left patches in priority and preference
      if (i.idx == 3 or i.idx == 2) and not @isPatchFree(a.p.n[4])
        i.priority -= 1
        resistanceModifier = 0.2
        preferred = true
        a.heading = @LEFT
      # if the patch to the left is occupied, bump up either of the right patches in priority and preference
      else if (i.idx == 4 or i.idx == 0) and not @isPatchFree(a.p.n[3])
        i.priority -= 1
        resistanceModifier = 0.2
        preferred = true
        a.heading = @RIGHT

      if @random(Math.round(@resistance(i.patch)*resistanceModifier)) == 0
        ps[i.priority] ||= []
        ps[i.priority].push i
        ps[i.priority].push {patch: i.patch} if preferred
        ps[i.priority].push {patch: i.patch} if preferred

    n = -1
    while not destinations? and n++ < 5
      destinations = ps[n]

    if destinations?
      # if one is the direction we're heading, chose it. Otherwise, randomly select.
      dests = []
      for d in destinations
        if ABM.util.inCone a.heading, @CONE, 2, a.x, a.y, d.patch.x, d.patch.y
          dests.push d

      if dests.length == 0
        dests = destinations
      dest = destinations[@random(dests.length)]
      if dest?
        a.moveTo dest.patch
        return true

    return false

  evaporateWater: ->
    for a in @rain
      if a? and a.p.isOnAirSurface and @random(10000) < @evapProbability
        # move to the surface of any pools of water
        nextP = a.p.n4[3]
        while nextP? and nextP.agentsHere().length > 0
          nextP = nextP.n4[3]
        @_changeToEvap a, nextP

  _changeToEvap: (a, nextP)->
    @_toDoAtEnd.push ->
      a = a.changeBreed(@evap)[0]
      a.moveTo nextP if nextP?

  moveEvaporation: (a)->
    return unless a?
    a.heading = ABM.util.degToRad(@random(90)+45)
    if a.y+1 > @world.maxY
      a.die()
      return

    # keep agents within the left-right bounds of the model
    if (a.heading > @UP and a.x-1 < @world.minX) or
       (a.heading < @UP and a.x+1 > @world.maxX)
      a.heading = @UP + (@UP - a.heading)

    a.forward 1

  moveWellWater: (w)->
    w.heading = @UP
    w.forward 5

    if w.p.type is "sky"
      if w.well instanceof WaterRemovalWell
        @_toKill.push w
      else if w.well instanceof IrrigationWell
        # rain it down onto the area around the well
        @_toDoAtEnd.push =>
          s = w.changeBreed(@spray)[0]
          s.speed = ABM.util.randomFloat @sprayIntensity
          s.heading = ABM.util.randomFloat @LEFT

  suckUpWellWater: ->
    for w in @wells
      for x,i in [(w.x-3),(w.x+3)]
        for y in [(w.depth)..(w.depth+5)] by 1
          p = @patches.patchXY x, y
          destX = if i == 0 then (w.x-1) else (w.x+1)
          agents = p.agentsHere()
          for a in agents
            if a.breed.name is "rain"
              a.setXY destX, y
              @_changeToWellWater a, w

  _changeToWellWater: (a, well) ->
    @_toDoAtEnd.push ->
      ww = a.changeBreed(@wellWater)[0]
      ww.well = well

  moveSpray: (s)->
    # use vector addition to continually add "gravity" until it hits the surface, then change to @rain
    origin = [s.x, s.y]
    s.forward s.speed
    s.heading = @DOWN
    s.forward 1
    patch = s.p
    if patch.type isnt "sky"
      # move it back to the surface and change its type to @rain
      while patch.type isnt "sky"
        patch = patch.n4[3]

      @_toDoAtEnd.push =>
        r = s.changeBreed(@rain)[0]
        r.moveTo patch
    else
      s.heading = ABM.util.radsToward origin[0], origin[1], s.x, s.y
      s.speed = ABM.util.distance origin[0], origin[1], s.x, s.y

  addRainSpotlight: ->
    # try to add spotlight to a raindrop at very top
    foundOne = false
    for a in @rain
      if a? and a.y > @patches.maxY-5
        foundOne = true
        @setSpotlight a
        break
    if not foundOne
      # if we did not find one, add spotlight to random raindrop
      a = @rain.oneOf()
      @setSpotlight a

  removeSpotlight: ->
    @setSpotlight null

  setTemplate: (str)->
    @template = str
    @reset()

  rainCount: (centerPatch, dx, dy, surfaceOnly = true, highlight = false)->
    pSet = @patches.patchRect centerPatch, dx, dy, true
    count = 0
    for p in pSet
      continue if surfaceOnly and p.type isnt "sky"
      agents = p.agentsHere()
      for a in agents
        count++ if a.breed is @rain

    if highlight
      ctx = @contexts.drawing
      ctx.save()
      ctx.translate centerPatch.x - dx, centerPatch.y - dy
      ctx.strokeStyle = '#fbf9c0'
      ctx.strokeRect 0, 0, (dx*2+1), (dy*2+1)
      ctx.restore()
      setTimeout ->
        ctx.save()
        ctx.translate centerPatch.x - dx - 1, centerPatch.y - dy - 1
        ctx.clearRect 0, 0, (dx*2+3), (dy*2+3)
        ctx.restore()
      , 250
    return count

class WaterRemovalWell extends Well
  @WELL_HEAD_TYPES: ["sky"]
  @WELL_IMG: ABM.util.importImage 'img/well-head-removal.png'

class IrrigationWell extends Well
  @WELL_HEAD_TYPES: ["sky"]
  @WELL_IMG: ABM.util.importImage 'img/well-head-irrigation.png'

class TileControl
  tileData: null
  model: null

  constructor: (@model)->
    @tileData = {}

  addTile: (type, imgUrl, callback)->
    setTimeout =>
      ABM.util.importImage imgUrl, (img)=>
        ctx = ABM.util.imageToCtx(img)
        data = ABM.util.ctxToImageData(ctx).data
        @tileData[type] = { data: data, width: img.width, height: img.height }
        console.log "Setting tile data (" + type + "): ", data

        setTimeout ->
          callback.call()
        , 1
    , 1

  lookupColor: (p)->
    if p? and p.type? and (data = @tileData[p.type])?
      # figure out the x and y points in the tile that we need
      tx = (p.x - @model.patches.minX) % data.width
      ty = (p.y - @model.patches.minY) % data.height

      pIdx = (tx + (ty * data.width)) * 4
      retColor = [data.data[pIdx], data.data[pIdx+1], data.data[pIdx+2], data.data[pIdx+3]]
      return retColor
    else
      return switch p.type
        when "sky"   then [205, 237, 252]
        when "soil"  then [232, 189, 174]
        when "rock1" then [196, 162, 111]
        when "rock2" then [123,  80,  56]
        when "rock3" then [113, 115, 118]
        when "rock4" then [ 33,  42,  47]

  _getCanvas: (type)->
    if (canvas = $('#canvas-tile-'+type)[0])?
      return canvas

    return $('<canvas>').attr(
      id: 'canvas-tile-'+type
    ).css(
      display: 'none'
    ).appendTo('body')[0]

window.WaterRemovalWell = WaterRemovalWell
window.IrrigationWell = IrrigationWell
window.WaterModel = WaterModel
