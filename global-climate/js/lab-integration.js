/*jshint indent: false, quotmark: false */
/*global window, iframePhone */

(function() {
  "use strict";

  window.setupLabCommunication = function(model) {
    var phone = iframePhone.getIFrameEndpoint();
    var isOceanModel = typeof(model.getOceanCO2Count) === 'function';

    // Register Scripting API functions.
    function registerModelFunc(name) {
      phone.addListener(name, function() {
        model[name].apply(model, arguments);
        model.draw();
      });
      phone.post('registerScriptingAPIFunc', name);
    }

    function registerCustomFunc(name, func) {
      phone.addListener(name, func);
      phone.post('registerScriptingAPIFunc', name);
    }

    registerCustomFunc('play', function() {
      model.start();
      // Notify iframe model that we received 'play' message and reacted appropriately.
      phone.post('play.iframe-model');
    });
    registerCustomFunc('stop', function() {
      model.stop();
      // Notify iframe model that we received 'stop' message and reacted appropriately.
      phone.post('stop.iframe-model');
    });
    registerCustomFunc('step', function(content) {
      var steps = content;
      while (steps--) model.step();
      model.draw()
    });
    registerModelFunc('createCO2');
    registerModelFunc('createVapor');
    registerModelFunc('addCO2');
    registerModelFunc('subtractCO2')
    registerModelFunc('addCloud');
    registerModelFunc('subtractCloud');
    registerModelFunc('updateVapor');
    registerModelFunc('updateClouds');
    registerModelFunc('updateIce');
    registerModelFunc('erupt');
    registerModelFunc('addSunraySpotlight');
    registerModelFunc('addCO2Spotlight');
    registerModelFunc('removeSpotlight');
    registerModelFunc('hide90');
    registerModelFunc('showAll');

    // Properties.
    // initialTemperature property is used to calculate temperature change outputs (see below).
    var initialTemperature = model.getTemperature();
    phone.addListener('set', function (content) {
      switch(content.name) {
        // Due to async nature of iframe communication, Lab needs to setup initial temperature explicitly
        // if it also changes temperatue (e.g. fixedTemperature property) during initial setup.
        case 'initialTemperature':
          initialTemperature = content.value;
          break;
        case 'temperature':
          model.temperature = content.value;
          break;
        case 'temperaturePerHeat':
          model.temperaturePerHeat = content.value;
          break;
        case 'albedo':
          model.setAlbedo(content.value);
          break;
        case 'sunBrightness':
          model.setSunBrightness(content.value);
          break;
        case 'animRate':
          model.anim.setRate(content.value, false);
          break;
        case 'showGases':
          model.showGases(content.value);
          break;
        case 'showRays':
          model.showRays(content.value);
          break;
        case 'showHeat':
          model.showHeat(content.value);
          break;
        case 'keyLabels':
          model.restrictKeyLabelsTo = content.value;
          break;
        case 'includeWaterVapor':
          model.setIncludeWaterVapor(content.value);
          break;
        case 'oceanAbsorbtionChangable':
          model.setOceanAbsorbtionChangable(content.value);
          break;
        case 'oceanCO2Absorbtion':
          model.oceanCO2Absorbtion = content.value;
          break;
        case 'useFixedTemperature':
          model.setUseFixedTemperature(content.value);
          break;
        case 'fixedTemperature':
          model.setFixedTemperature(content.value);
          break;
        case 'oceanTemperature':
          model.oceanTemperature = content.value;
          break;
        case 'nCO2Emission':
          model.nCO2Emission = content.value;
          break;
        case 'humanEmissionRate':
          model.setHumanEmissionRate(content.value);
          break;
        case 'vaporPerDegreeModifier':
          model.vaporPerDegreeModifier = content.value;
          break;
        case 'cloudsFormedByVapor':
          model.cloudsFormedByVapor = content.value;
          break;
        case 'icePercent':
          model.setIcePercent(content.value);
          break;
        case 'iceFormedByTemperature':
          model.iceFormedByTemperature = content.value;
          break;
        case 'oceanZeroAbsorbtionTemp':
          model.oceanZeroAbsorbtionTemp = content.value;
          break;
      }
    });

    function getOutputs() {
      var result = {
        year: model.getFractionalYear(),
        temperatureChange: model.getTemperature() - initialTemperature,
        CO2Concentration: model.getCO2Count(),
        // Spotlight may be automatically deactivated when an observed agent leaves the model.
        // Notify Lab model about that using output.
        spotlightActive: !!climateModel.spotlightAgent
      };
      if (isOceanModel) {
        result.oceanTemperatureChange = model.oceanTemperature - initialTemperature;
        result.airCO2Concentration = model.getAtmosphereCO2Count();
        result.oceanCO2Concentration = model.getOceanCO2Count();
        result.vaporConcentration = model.getVaporCount();
      }
      return result;
    };

    // Set initial output values.
    phone.post('outputs', getOutputs());

    model.stepCallback = function() {
      // We could also write:
      // phone.post('outputs', { ... });
      // phone.post('tick');
      // However Lab supports outputs in 'tick' handler too, so we can send only one message.
      phone.post('tick', {
        outputs: getOutputs()
      });
    };

    phone.initialize();
  };
}());
