//
//  MenuMeterGPU.h
//
//  Constants for the GPU Meter
//

///////////////////////////////////////////////////////////////
//
//	Preference information
//
///////////////////////////////////////////////////////////////

#define kGPUIntervalPref				@"GPUInterval"
#define kGPUDisplayModePref				@"GPUDisplayMode"
#define kGPUGraphLengthPref				@"GPUGraphLength"
#define kGPUColorPref					@"GPUColor"
#define kGPUShowMemoryPref				@"GPUShowMemory"

// Display modes (bit flags, same pattern as CPU)
enum {
	kGPUDisplayPercent					= 1,
	kGPUDisplayGraph					= 2,
	kGPUDisplayThermometer				= 4
};
#define kGPUDisplayDefault				kGPUDisplayPercent

// Timer
#define kGPUUpdateIntervalMin			0.5
#define kGPUUpdateIntervalMax			10.0
#define kGPUUpdateIntervalDefault		1.0

// Graph width
#define kGPUGraphWidthMin				11
#define kGPUGraphWidthMax				88
#define kGPUGraphWidthDefault			33

// Thermometer
#define kGPUThermometerDisplayWidth		11.0f
#define kGPUPercentDisplayBorderWidth	2

// Color
#define kGPUColorDefault				[NSColor systemGreenColor]

// Show memory usage in menu bar next to %
#define kGPUShowMemoryDefault			NO
