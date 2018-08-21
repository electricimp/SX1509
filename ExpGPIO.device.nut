// MIT License
//
// Copyright 2013-8 Electric Imp
//
// SPDX-License-Identifier: MIT
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
// EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE


// This is a convenience class that simplifies the configuration of a IO Expander GPIO port.
// You can use it in a similar manner to hardware.pin with two main differences:
// 1. There is a new pin type: LED_OUT, for controlling LED brightness (basically PWM_OUT with "breathing")
// 2. The pin events will include the pin state as the one parameter to the callback
class ExpGPIO {
    _expander = null;  //Instance of an Expander class
    _gpio     = null;  //Pin number of this GPIO pin
    _mode     = null;  //The mode configured for this pin

    // This definition augments the pin configuration constants as defined in:
    // https://developer.electricimp.com/api/hardware/pin/configure
    static LED_OUT = 1000001;

    // Constructor requires the IO Expander class and the pin number to aquire
    constructor(expander, gpio) {
        _expander = expander;
        _gpio     = gpio;
    }

    // Optional initial state (defaults to 0 just like the imp)
    function configure(mode, param = null) {
        _mode = mode;

        if (mode == DIGITAL_OUT) {
            // Digital out - Param is the initial value of the pin
            // Set the direction, turn off the pull up and enable the pin
            _expander.setDir(_gpio,1);
            _expander.setPullUp(_gpio,0);
            if(param != null) {
                _expander.setPin(_gpio, param);
            } else {
                _expander.setPin(_gpio, 0);
            }

            return this;
        } else if (mode == ExpGPIO.LED_OUT) {
            // LED out - Param is the initial intensity
            // Set the direction, turn off the pull up and enable the pin
            // Configure a bunch of other LED specific timers and settings
            _expander.setPullUp(_gpio, 0);
            _expander.setInputBuffer(_gpio, 0);
            _expander.setOpenDrain(_gpio, 1);
            _expander.setDir(_gpio, 1);
            _expander.setClock(_gpio, 1);
            _expander.setLEDDriver(_gpio, 1);
            _expander.setTimeOn(_gpio, 0);
            _expander.setOff(_gpio, 0);
            _expander.setRiseTime(_gpio, 0);
            _expander.setFallTime(_gpio, 0);
            _expander.setIntensityOn(_gpio, param > 0 ? param : 0);
            _expander.setPin(_gpio, param > 0 ? 0 : 1);

            return this;
        } else if (mode == DIGITAL_IN) {
            // Digital in - Param is the callback function
            // Set the direction and disable to pullup
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,0);
            // Fall through to the callback setup
        } else if (mode == DIGITAL_IN_PULLUP) {
            // Param is the callback function
            // Set the direction and turn on the pullup
            _expander.setDir(_gpio,0);
            _expander.setPullUp(_gpio,1);
            // Fall through to the callback setup
        }

        if (typeof param == "function") {
            // If we have a callback, configure it against a rising IRQ edge
            _expander.setIrqMask(_gpio,1);
            _expander.setIrqEdges(_gpio,1,1);
            _expander.setCallback(_gpio, param);
        } else {
            // Disable the callback for this pin
            _expander.setIrqMask(_gpio,0);
            _expander.setIrqEdges(_gpio,0,0);
            _expander.setCallback(_gpio,null);
        }

        return this;
    }

    // Reads the stats of the configured pin
    function read() {
        return _expander.getPin(_gpio);
    }

    // Sets the state of the configured pin
    function write(state) {
        _expander.setPin(_gpio,state);
    }

    // Set the intensity of an LED OUT pin. Don't use for other pin types.
    function setIntensity(intensity) {
        _expander.setIntensityOn(_gpio,intensity);
    }

    // Set the blink rate of an LED OUT pin. Don't use for other pin types.
    function blink(rampup, rampdown, intensityon, intensityoff = 0, fade = true) {
        rampup = (rampup > 0x1F ? 0x1F : rampup);
        rampdown = (rampdown > 0x1F ? 0x1F : rampdown);
        intensityon = intensityon & 0xFF;
        intensityoff = (intensityoff > 0x07 ? 0x07 : intensityoff);

        _expander.setTimeOn(_gpio, rampup);
        _expander.setOff(_gpio, rampdown << 3 | intensityoff);
        _expander.setRiseTime(_gpio, fade?5:0);
        _expander.setFallTime(_gpio, fade?5:0);
        _expander.setIntensityOn(_gpio, intensityon);
        _expander.setPin(_gpio, intensityon>0 ? 0 : 1)
    }

    // Enable or disable fading (breathing)
    function fade(on, risetime = 5, falltime = 5) {
        _expander.setRiseTime(_gpio, on ? risetime : 0);
        _expander.setFallTime(_gpio, on ? falltime : 0);
    }
}
