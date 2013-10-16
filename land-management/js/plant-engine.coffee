
class PlantEngine

  u = ABM.util

  NORTH = Math.PI/2

  managementPlan = ["bare", "bare"]

  setupPlants: ->
    @agentBreeds "grass trees wheat"

    @trees.setDefaultShape "arrow"
    @trees.setDefaultColor [0,255,0]

    @addImage "tree1", "tree-1-sprite", 77, 140
    @addImage "tree2", "tree-2-sprite", 57, 160
    @addImage "tree3", "tree-3-sprite", 78, 160
    @addImage "grass1", "grass-1-sprite", 78, 160
    @addImage "grass2", "grass-1-sprite", 78, 160
    @addImage "wheat1", "wheat-1-sprite", 78, 160
    @addImage "wheat2", "wheat-1-sprite", 78, 160

  addImage: (name, id, width, height) ->
    image = document.getElementById(id)
    ABM.shapes.add name, false, (ctx)=>
      ctx.scale(-0.05, 0.05);
      ctx.translate(width,height)
      ctx.rotate Math.PI
      ctx.drawImage(image, 0, 0)
  
  ###
    Defines the planting system of the two zones. Zone is defined
    by index, 0 or 1.
  ###
  setZoneManagement: (zone, type) ->
    managementPlan[zone] = type

  manageZones: ->
    if managementPlan.join() is "bare,bare" then return

    @yearTick = @anim.ticks % (12 * @monthLength)

    if @yearTick is 1
      @plantPlants()

  plantPlants: ->
    zoneWidth = @patches.maxX

    for zone in [0, 1]
      plantType = managementPlan[zone]
      continue if plantType is "bare"
      continue if @anim.ticks > (12 * @monthLength) and not @plantData[plantType].annual

      quantity  = @plantData[plantType].quantity
      inRows    = @plantData[plantType].inRows
      xModifier = zone*2 - 1      # -1, 1

      for i in [0...quantity]
        x = if inRows then Math.floor((i+1) * zoneWidth/(quantity+1)) else u.randomInt(zoneWidth)
        x *= xModifier
        patch = @surfaceLand[zoneWidth + x]     # find surface patch with x coord

        @plantSeed plantType, patch

  plantSeed: (type, patch) ->
    data = @plantData[type]
    patch.sprout 1, @[type], (a)->
      a.size = 0
      a.type = type
      a.shape = u.oneOf data.shapes
      a.isSeed = true
      a.dying = false
      a.germinationDate = u.randomInt2 data.minGermination, data.maxGermination

  runPlants: ->
    killList = []

    for a in @agents
      if a.isSeed
        if @yearTick is a.germinationDate
          a.isSeed = false
      else
        if @month < 10
          a.size += @plantData[a.type].growthRate unless a.size > @plantData[a.type].maxSize
        else if @plantData[a.type].annual
          if not a.dying 
            if u.randomInt(50) is 1 then a.dying = true
          if a.dying
            a.size -= @plantData[a.type].growthRate unless a.size <= 0
          if @yearTick is (12 * @monthLength) - 1
            killList.push a

    a.die() for a in killList


  plantData:
    trees:
      quantity: 15
      inRows: false
      annual: false
      minGermination: 40
      maxGermination: 500
      growthRate: 0.004
      maxSize: 3.2
      shapes: ["tree1", "tree2", "tree3"]
    grass:
      quantity: 25
      inRows: false
      annual: false
      minGermination: 1
      maxGermination: 150
      growthRate: 0.01
      maxSize: 1.2
      shapes: ["grass1", "grass2"]
    wheat:
      quantity: 20
      inRows: true
      annual: true
      minGermination: 10
      maxGermination: 70
      growthRate: 0.01
      maxSize: 1.5
      shapes: ["wheat1", "wheat2"]

window.PlantEngine = PlantEngine