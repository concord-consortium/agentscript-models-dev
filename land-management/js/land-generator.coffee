SKY_COLOR = [131, 216, 240]
LIGHT_LAND_COLOR = [135, 79, 49]
DARK_LAND_COLOR = [105, 49, 19]

SKY  = "sky"
LAND = "land"

MAX_INTERESTING_SOIL_DEPTH = 6

class LandGenerator

  u = ABM.util

  amplitude = -4

  setupLand: ->

    @skyPatches = []
    @landPatches = []

    for p in @patches
      p.zone = if p.y <= 0 then 1 else 2
      if p.y > @landShapeFunction p.x
        p.color = SKY_COLOR
        p.type = SKY
        p.depth = -1
        @skyPatches.push p
      else
        p.color = DARK_LAND_COLOR
        p.type = LAND
        p.depth = MAX_INTERESTING_SOIL_DEPTH
        p.eroded = false
        p.erosionDirection = 0
        @landPatches.push p

    @setSoilDepths()


  setLandType: (type) ->
    switch type
      when "Nearly Flat"  then amplitude = -0.00001
      when "Plain"        then amplitude = -4
      when "Rolling"      then amplitude = -10
      when "Hilly"        then amplitude = -20
      else                     amplitude = 0

  landShapeFunction: (x) ->
    amplitude * Math.sin( u.degToRad(x - 10) )

window.LandGenerator = LandGenerator