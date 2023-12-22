#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=1				// Use modern global access method.
#define DemoMode				// To disable DemoMode, put two slashes in front the the hash sign on this line to comment it out. To enable DemoMode, delete the two slashes.
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	jScan
////	(c) Jesper Sjöström, 25 Nov 2013
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	Simple scan software mainly created to manage flexible 1p uncaging.
////	As of 4 Dec 2017, this software also requires the MultiPatch software.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	NOTES
////	25 Nov 2013. JSj
////	*	Beginning code 
////	*	Made panel and some of the wrapper code.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	18-19 Feb 2014. JSj
////	*	Hacked entire scan and random uncaging environment and got the first images
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	26 Feb 2014. JSj
////	*	Fixed LUT bug
////	*	Synchronized scanning and sampling clocks to fix pesky alignment bug.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	27 Feb 2014. JSj
////	*	Added TIFF header for saved frames
////	*	Added waveNote for save uncaging patterns
////	*	Moved uncaging controls to their own panel
////	*	Added XYZ stage communication wrapper
////	*	Added stack acquisition wrapper
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	28 Feb 2014. JSj
////	*	Added averaging of frames
////	*	Added acquisition of non-averaged frames ("movies")
////	*	Now communicates properly with XYZ stage
////	*	Added acquisition of stacks, three channels, with averaging.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	5 Mar 2014. JSj
////	*	Storing corrected *actual* sampling frequency in TIFF header
////	*	Fixed bug with zoom setvar not updating zoom, only buttons
////	*	Added binning of pixels
////	*	Added automatic timed repetition of uncaging runs
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	13 Mar 2014. JSj
////	*	Added rotation of imaging, which also applies to uncaging points in an identical manner.
////	*	Added settings file "jScan_settings.txt" for COM port etc to startup smoothly on different rigs
////	*	Debugged uncaging to make sure it runs well with ephys software: rewired AO trig on PCI-6110 software-wise to output
////		on pin PFI6, to ensure backwards compatibility with ScanImage trigger wiring.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	26 Mar 2014. JSj
////	*	Added linscans
////	*	Added Quick Settings buttons
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	28 Mar 2014. JSj
////	*	Quick Settings are now loaded from the settings file (as are any other EXISTING variables/strings in the settings file)
////	*	Now saves interrupted stack by default. Also grabs, although that may only work with movies, not averaged frames.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	4 Apr 2014. JSj
////	*	Uncaging sweeps are now saved with a suffix that counts up rather than with a stupid timestamp, like I did before.
////	*	Procedure jSc_stopWaveformAndScan fixes nasty bug where stupid error due to stopping a non-running process
////		results in knock-on errors in MultiPatch.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	28 Sep 2015. JSj
////	*	Various user-friendliness tweaks
////	*	Fixed nasty bug: Upsampled raster output to account for binfactor on input, since output runs on input sampling clock.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	11 Jan 2017. JSj
////	*	Stack acquisition EndOfScanHook had a typo that caused a bizarre error.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	27 Nov 2017. JSj
////	*	In v02, implemented conditional compilation to enable programming on non-rig computers.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	4 Dec 2017. JSj
////	*	Added an automatic STDP function, so that differently timed spikes are paired with all "uncaged" inputs, although
////		with different timings. This required integration with the MultiPatch software; there will be knock-on effects and bugs
////		due to this, no doubt. This relies on SpTm2Wv function in MultiPatch. jScan therefore needs MultiPatch to run.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	30 Aug 2018. JSj
////	*	Reversed the sign convention for dT in the Uncaging Panel, to conform with my Neuron 2001 paper and other papers.
////	*	Added a feature to the Uncaging Panel so that postsynaptic current injections for evoking spikes can be eliminated in
////		specific patterns, e.g. every other pulse etc.
////	*	Added a feature to the Uncaging Panel so that postsynaptic current injections for evoking spikes can be temporally shifted
////		in specific patterns, e.g. for the production of alternating pre-post and post-pre timings.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	22 Jan to 1 Aug 2020. JSj
////	*	Created v03
////	*	Created a 2p Zap panel for 2-photon optogenetics purposes.
////	*	Made an interface for easily picking candidate presynaptic cells.
////	*	Converted cell locations to a voltage scan path for driving the galvos.
////	*	Added Archimedean spirals for uncaging points.
////	*	Added separate input, output, shutter, and ETL devices.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	22 Aug 2020. JSj
////	*	Automatic picking of cells for 2p zap based on simple thresholding and particle count in binary image.
////	*	Plotting both picked points and 2p zap voltage path over the source bitmap image.
////	*	Prepared Run Pattern for use with 2p zap (changed all naming from "unc" to "stim" where it generally applies to both).
////	*	Realized that "no spikes" and "offset spikes" already works with 2p zap path maker, so implemented that too.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	26 Aug 2020. JSj
////	*	Figured out the triggering across imaging and ephys boards. Yes, again.
////	*	Adding pre-pad and post-pad to shutter waves to account for shutter opening and closing delays.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	31 Aug 2020. JSj
////	*	Added manual thresholding to 2p Zap cell autodetect button; auto thresholding did not work with pipette present.
////	*	Fixed bugs associated with trying to save uncaging waves when doing 2p zap.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	2 Sep 2020. JSj
////	*	Fixed bug in jSc_calcCorrectedmspl, it did not correctly adjust for jSc_pixelBin pixel binning.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	8 Sep 2020. JSj
////	*	Added ETL slider to Main and Stack windows.
////	*	Added stack acquisition based on ETL alone.
////	*	Fixed bug so that number of slices in stack is calculated correctly (missing last one due to rounding error).
////	*	TIFF header now contains stack acquistion information.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	16 Sep 2020. JSj
////	*	jSc_COM_WaitUntilMoveDone now updates XYZ coordinates while waiting.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	14 Mar 2021. JSj
////	*	Added a Spike List Editor for easier representation and editing of spike lists for 2p Zap and Uncaging
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	25 Mar 2021. JSj
////	*	Spike List Editor now reads found responses from the MultiPatch Load Recently Acquired data panel into the noSpikesList, 
////		such that EPSP found --> postsynaptic spiking for that location.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	26 Mar 2021. JSj
////	*	Decided to deprecate the MultiPatch Load Recently Acquired data panel and instead use the response detector in
////		Jesper's Tools Load Waves panel. The two panels were too similar, so I went with the more flexible one.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	29 Mar 2021. JSj
////	*	jScan now also saves jSc_pointsX, jSc_pointsY, and jSc_pointsN with jSc_stim_Suffix at end of pattern.
////	*	jScan now also saves jSc_xAmp and jSc_yAmp in the wave note.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	13 Apr 2021. JSj
////	*	Edit Spike List panel was not resized right. Fixed this.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	16 Apr 2021. JSj
////	*	No-spike list and offset-spike list are now automatically adjusted in size when user adds/removes a zap point.
////		WARNING! Weird bugs may ensue!
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	6 May 2021. JSj
////	*	Bug fix: TIFF file save path was changed from 'home' to 'jScPath'.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	14 Jan 2022. JSj
////	*	2p Zap now acquires data from channels 1 & 2 during stimulation. Note that this moved the EndOfScanHook from AO to AI. Also, the acquired data is raw, not sensitive to
////		user-chosen channels, not sensitive to binning, and always on for channels 1 & 2. This data is meant to be used for detection of presynaptic spikes during 2p stimulation.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	23 Mar 2022. JSj
////	*	2p Zap can now stagger the last spikes across channels, so that in a quad recording, spikes and monosynaptic responses do not collide.
////	*	Pad after last spikes adds some space so that the user can stagger the last spikes by more than the dwell time without running out of space in the output wave.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	16 Dec 2022. JSj
////	*	Started jScan_v04
////	*	Started adding a BurstFrames feature, where output data is repeated nBurstFrames times and input data scaled accordingly so that very rapid framescans can be executed.
////		Note that BurstFrames eat up memory fast, so are only intended for very small framescans that are execute at e.g. >80 Hz frame rate.
////	*	Started adding a Loop button, which executes Grab once every loop interval. This is not stack compatible, but should be nFrames and nBurstFrames compatible.
////	*	Added jSc_BoardBitScaling parameter for the input board. Rationale: We want images in bit values, not in voltage values, but DAQmx_Scan /AVE bin-averaging flag does not
////		function with unsigned integer images, so image data must be floating to allow NI library-driven averaging. But floating-value images are acquired as voltages, which
////		is not a meaningful data representation. This is because we want to know when we are close to saturation and also how well we are using all available bits on the
////		input board. 
////		--- *** Remember to set jSc_BoardBitScaling in settings file! **** ---
////	*	Improved demo mode with simulated acquired data and faked end-of-scan hook.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	12 Jan 2023. JSj
////	*	Worked on BurstFrames feature, updating jSc_initGrabStorage, jSc_makeAORasterData, jSc_makeAIRasterData, jSc_raw2image, and jSc_transferGrab2storage.
////	*	Created jSc_makeBurstFrames.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	13 Feb 2023. JSj
////	*	Bug in BurstFrames checkbox proc such that this function was never engaged.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	14 Feb 2023. JSj
////	*	BurstFrames mode now stores correctly in the quick settings
////	*	Fixed subtle bug where upsampling loses jSc_pixelBin-1 points at the end of wave, causing slow drift of frame in burstFrames
////	*	Now reports in panel on the post-hoc corrected sample rate, line rate, and frame rate.
////	*	Loop and Grab buttons seem to behave correctly.
////	*	Tested that stack acquisition still works, although I did turn off burst frame mode during stack acquisition.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// TO-DO LIST AND POSSIBLE BUGS:
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////	*	Make sure binary TIFF file format is correctly saved WRT the number of bits. As of 16 Dec 2022, I think it is doing it correctly, provided board bit range is set right
////		in the settings file. DO THIS!!!
////	*	Allow negative bit values or not? Presently negative values are discarded! Rig 3 has negative values on one of the PMTs, so this is likely wrong. This affects bit range
////		since int16 is not uint16, see above. If we work with int16 instead of uint16, it is possible jSc_BoardBitScaling should be 2^11 for a 12-bit board, etc.
////	*	Transfer imaging data to windows on the fly, i.e., like "striping" in ScanImage
////	*	Rewrite code to use FIFO so that you can do properly timed framescans (Note to self: this disallows DAQmx_Scan /AVE bin-averaging, because FIFO data has to be int16)
////	*	Add setting: Skip first x number of pixels in line to account for slow mechanical shutters causing blanking of part of first scan line.
////	*	jSc_COM_Scaling should move from jSc_initComPort to a regular variable and be in the settings file
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

menu "Macros"
	"Init jScan",init_jScan()
	"jScan to front",jSc()
	SubMenu "Tools and debug"
		"Open save path in OS",PathInfo/SHOW jScPath
		SubMenu "Debug graphs"
			"Show raster-scan voltages in 2D",jSc_makeRasterVoltagesGraph()
			"Show raster-scan voltages over time",jSc_makeRasterVoltagesGraph2()
			"Show uncaging sweep voltages in 2D",jSc_MakeUncVoltagesGraph()
			"Show uncaging sweep voltages over time",jSc_MakeUncVoltagesGraph2()
			"Show uncaging grid graph",jSc_MakePseudoUncGraph()
			"Show Archimedean spiral",jSc_plotArchimedeanSpiral()
			"Make all debug graphs",jSc_MakeDebugGraphs()
			"Close all debug graphs",jSc_CloseDebugGraphs()
			"Spiral sep vs shutter time",jSc_calibrateSpiral()
		End
		"Dump parameters",jSc_dumpParams()
		"Print most recent NI error",jSc_printError()
		"Toggle verbose mode",jSc_toggleVerboseMode()
		"Zero XYZ stage coordinate system",jSc_COM_zero()
	end
	SubMenu "Laser beam control"
		"Open mechanical shutter",jSc_openShutter()
		"Close mechanical shutter",jSc_closeShutter()
		"Centre laser beam",jSc_parkLaser(0,0)
		"Park laser beam to the side",jSc_parkLaser(jSc_max_xAmp,jSc_max_yAmp)
		"Open galvo shutter",jSc_parkGalvoShutter(jSc_stim_shutterOpen)
		"Close galvo shutter",jSc_parkGalvoShutter(jSc_stim_shutterClosed)
	end
	"-"
end

Function jSc_toggleVerboseMode()
	
	NVAR		jSc_VerboseMode
	
	jSc_VerboseMode = jSc_VerboseMode ? 0 : 1
	if (jSc_VerboseMode)
		print "Verbose mode is now on."
	else
		print "Verbose mode is now off."
	endif

End

Function init_jScan()

	// General
	JT_GlobalVariable("jSc_rig",0,"Rig4",1)						// Rig identifier

	// Board parameters
	// PCI-6110 is Dev2 --> AD
	// PCIe-6363 is Dev3 --> DA
	JT_GlobalVariable("jSc_inDevStr",0,"Dev2",1)				// Input device name string
	JT_GlobalVariable("jSc_BoardBitScaling",4096,"",0)			// Board bit scaling, e.g. 4096 for 12 bits, or 65536 for 16 bits
	JT_GlobalVariable("jSc_outDevStr",0,"Dev3",1)				// Output device name string
	JT_GlobalVariable("jSc_shutterDevStr",0,"Dev2",1)			// Shutter device name string
	JT_GlobalVariable("jSc_shutterPin",3,"",0)					// Which pin is the shutter located at
	JT_GlobalVariable("jSc_gateOut",2,"",0)						// Which analog output is the gate signal sent at
	
	// ETL parameters
	JT_GlobalVariable("jSc_ETLexists",1,"",0)					// Boolean: ETL is installed
	JT_GlobalVariable("jSc_ETLDevStr",0,"Dev3",1)				// Electrically tunable device name string
	JT_GlobalVariable("jSc_ETLout",3,"",0)						// Which analog output is the ETL located at
	JT_GlobalVariable("jSc_ETLcommand",0,"",0)					// ETL command value
	JT_GlobalVariable("jSc_ETLscaling",100,"",0)				// ETL scaling [µm/V] (sign matters)
	JT_GlobalVariable("jSc_ETLoffset",5,"",0)					// ETL offset [V]
	JT_GlobalVariable("jSc_ETLmicron",0,"",0)					// ETL effective focus position [µm]
	JT_GlobalVariable("jSc_ETLmin",0,"",0)						// ETL minimum value [V]
	JT_GlobalVariable("jSc_ETLmax",10,"",0)						// ETL maximum value [V]

	// Scan parameters
	JT_GlobalVariable("jSc_maxNFrames",200,"",0)				// Maximum number of frames during scan operations
	JT_GlobalVariable("jSc_nFrames",1,"",0)						// Number of frames to acquire during grab operations
	JT_GlobalVariable("jSc_frameCounter",0,"",0)				// Counts frames during scan and grab operations
	JT_GlobalVariable("jSc_nLoops",10,"",0)						// Number of loops to acquire during loop operations
	JT_GlobalVariable("jSc_loopCounter",0,"",0)					// Counts loops during loop operations
	JT_GlobalVariable("jSc_loopPeriod",10,"",0)					// Period between grabs during loop operations (seconds)
	JT_GlobalVariable("jSc_LoopFlag",0,"",0)					// Boolean: Running loop right now?
	JT_GlobalVariable("jSc_burstFrames",0,"",0)					// Boolean: Frame burst during grab operations?
	JT_GlobalVariable("jSc_nBurstFrames",10,"",0)				// Number of frames to be burst-acquired
	JT_GlobalVariable("jSc_averageFrames",1,"",0)				// Boolean: Average frames during grab operations?
	JT_GlobalVariable("jSc_PathStr",0,"<empty path>",1)			// Save path
	JT_GlobalVariable("jSc_baseName",0,"exp_01_",1)				// Base name
	JT_GlobalVariable("jSc_suffix",1,"",0)						// Suffix for next file to be saved
	JT_GlobalVariable("jSc_scanAngle",0,"",0)					// Scan angle (degrees)
	JT_GlobalVariable("jSc_mspl",8,"",0)						// Milliseconds per line
	JT_GlobalVariable("jSc_flyback",2,"",0)						// Time alotted for flyback in milliseconds
	JT_GlobalVariable("jSc_totmspl",8,"",0)						// Total number of milliseconds per line
	JT_GlobalVariable("jSc_corrtotmspl",8,"",0)					// Total number of milliseconds per line corrected for actual sample rate
	JT_GlobalVariable("jSc_actualSampFreq",0,"",0)				// Actual sample rate (Hz)
	JT_GlobalVariable("jSc_reportStr",0,"<stats here>",1)		// Performance report string
	JT_GlobalVariable("jSc_actualFPS",0,"",0)					// Actual frames per second (Hz)
	JT_GlobalVariable("jSc_pixelBin",8,"",0)					// Binning of samples per pixel (this increases the effective sampling rate!)
	JT_GlobalVariable("jSc_pxpl",256,"",0)						// Number of pixels per line
	JT_GlobalVariable("jSc_lnpf",256,"",0)						// Number of lines per frame
	JT_GlobalVariable("jSc_xAmp",2.5,"",0)						// Scan amplitude (V), x axis
	JT_GlobalVariable("jSc_yAmp",2.5,"",0)						// Scan amplitude (V), y axis
	JT_GlobalVariable("jSc_xPad",0.05,"",0)						// Fast axis padding: this is how much the mirrors swing outside the FOV defined by xAmp & yAmp
	JT_GlobalVariable("jSc_max_xAmp",3.5,"",0)					// Maximum scan amplitude (V), x axis
	JT_GlobalVariable("jSc_max_yAmp",3.5,"",0)					// Maximum scan amplitude (V), y axis
	JT_GlobalVariable("jSc_max_xPad",0.2,"",0)					// Maximum scan amplitude (V), x axis pad
	JT_GlobalVariable("jSc_ZoomFactor",1,"",0)					// Zoom factor
	JT_GlobalVariable("jSc_Ch1on",1,"",0)						// Boolean: Scan channel #1
	JT_GlobalVariable("jSc_Ch2on",1,"",0)						// Boolean: Scan channel #2
	JT_GlobalVariable("jSc_Ch3on",1,"",0)						// Boolean: Scan channel #3
	JT_GlobalVariable("jSc_imSize",350,"",0)					// Size of window showing the frames
	JT_GlobalVariable("jSc_ScanFlag",0,"",0)					// Boolean: Scanning right now?
	JT_GlobalVariable("jSc_GrabFlag",0,"",0)					// Boolean: Now grabbing?
	JT_GlobalVariable("jSc_VerboseMode",0,"",0)					// Boolean: Dump a lot of debug information or not?
	JT_GlobalVariable("jSc_vRange1",10,"",0)					// +/- input voltage range, channel #1 (V)
	JT_GlobalVariable("jSc_vRange2",10,"",0)					// +/- input voltage range, channel #2 (V)
	JT_GlobalVariable("jSc_vRange3",0.5,"",0)					// +/- input voltage range, channel #3 (V)
	JT_GlobalVariable("jSc_LUTno1",20,"",0)						// LUT choice, channel 1
	JT_GlobalVariable("jSc_LUTno2",19,"",0)						// LUT choice, channel 2
	JT_GlobalVariable("jSc_LUTno3",1,"",0)						// LUT choice, channel 3
	JT_GlobalVariable("jSc_LUTstart1",0,"",0)					// LUT start, channel 1
	JT_GlobalVariable("jSc_LUTend1",500,"",0)					// LUT end, channel 1
	JT_GlobalVariable("jSc_LUTstart2",0,"",0)					// LUT start, channel 2
	JT_GlobalVariable("jSc_LUTend2",500,"",0)					// LUT end, channel 2
	JT_GlobalVariable("jSc_LUTstart3",0,"",0)					// LUT start, channel 3
	JT_GlobalVariable("jSc_LUTend3",500,"",0)					// LUT end, channel 3
	JT_GlobalVariable("jSc_LUTauto1",0,"",0)					// Boolean: LUT auto-scaled, channel 1?
	JT_GlobalVariable("jSc_LUTauto2",0,"",0)					// Boolean: LUT auto-scaled, channel 2?
	JT_GlobalVariable("jSc_LUTauto3",1,"",0)					// Boolean: LUT auto-scaled, channel 3?
	JT_GlobalVariable("jSc_LSflag",0,"",0)						// Boolean: Linescan?
	printf "\r"

	// --- Define Quick Settings ---
	// Remember that you have to define variables to be read even if they are not used.
	// For example, if jSc_QS1_burstFrames is not created here, then it cannot be read from the jScan_settings.txt file.
	// You also need to define settings variables to be read in the jSc_QS_pList parameter list below.

	// Default Quick Settings #1 -- fast framescan for viewing
	JT_GlobalVariable("jSc_QS1_name",0,"fast framescan",1)			// Quick-setting identifier
	JT_GlobalVariable("jSc_QS1_nFrames",3,"",0)						// Number of frames to acquire during grab operations
	JT_GlobalVariable("jSc_QS1_averageFrames",1,"",0)				// Boolean: Average frames during grab operations?
	JT_GlobalVariable("jSc_QS1_burstFrames",0,"",0)					// Boolean: Burst frames mode during grab operations?
	JT_GlobalVariable("jSc_QS1_nBurstFrames",10,"",0)				// Number of frames in burstFrames mode
	JT_GlobalVariable("jSc_QS1_scanAngle",0,"",0)					// Scan angle (degrees)
	JT_GlobalVariable("jSc_QS1_mspl",2,"",0)						// Milliseconds per line
	JT_GlobalVariable("jSc_QS1_flyback",0.5,"",0)					// Time alotted for flyback in milliseconds
	JT_GlobalVariable("jSc_QS1_pixelBin",4,"",0)					// Binning of samples per pixel (this increases the effective sampling rate!)
	JT_GlobalVariable("jSc_QS1_pxpl",512,"",0)						// Number of pixels per line
	JT_GlobalVariable("jSc_QS1_lnpf",128,"",0)						// Number of lines per frame
	JT_GlobalVariable("jSc_QS1_xAmp",2,"",0)						// Scan amplitude (V), x axis
	JT_GlobalVariable("jSc_QS1_yAmp",2,"",0)						// Scan amplitude (V), y axis
	JT_GlobalVariable("jSc_QS1_xPad",0.05,"",0)						// Fast axis padding: this is how much the mirrors swing outside the FOV defined by xAmp & yAmp
	JT_GlobalVariable("jSc_QS1_ZoomFactor",1,"",0)					// Zoom factor
	JT_GlobalVariable("jSc_QS1_Ch1on",1,"",0)						// Boolean: Scan channel #1
	JT_GlobalVariable("jSc_QS1_Ch2on",1,"",0)						// Boolean: Scan channel #2
	JT_GlobalVariable("jSc_QS1_Ch3on",1,"",0)						// Boolean: Scan channel #3
	JT_GlobalVariable("jSc_QS1_imSize",250,"",0)					// Size of window showing the frames
	JT_GlobalVariable("jSc_QS1_vRange1",10,"",0)						// +/- input voltage range, channel #1 (V)
	JT_GlobalVariable("jSc_QS1_vRange2",10,"",0)						// +/- input voltage range, channel #2 (V)
	JT_GlobalVariable("jSc_QS1_vRange3",0.5,"",0)					// +/- input voltage range, channel #3 (V)
	JT_GlobalVariable("jSc_QS1_LUTstart1",0,"",0)					// LUT start, channel 1
	JT_GlobalVariable("jSc_QS1_LUTend1",500,"",0)					// LUT end, channel 1
	JT_GlobalVariable("jSc_QS1_LUTstart2",0,"",0)					// LUT start, channel 2
	JT_GlobalVariable("jSc_QS1_LUTend2",500,"",0)					// LUT end, channel 2
	JT_GlobalVariable("jSc_QS1_LUTstart3",0,"",0)					// LUT start, channel 3
	JT_GlobalVariable("jSc_QS1_LUTend3",500,"",0)					// LUT end, channel 3
	JT_GlobalVariable("jSc_QS1_LUTauto1",0,"",0)					// Boolean: LUT auto-scaled, channel 1?
	JT_GlobalVariable("jSc_QS1_LUTauto2",0,"",0)					// Boolean: LUT auto-scaled, channel 2?
	JT_GlobalVariable("jSc_QS1_LUTauto3",1,"",0)					// Boolean: LUT auto-scaled, channel 3?
	JT_GlobalVariable("jSc_QS1_LSflag",0,"",0)						// Boolean: Linescan?
	printf "\r"

	// Default Quick Settings #2 -- slow framescan for acquiring morphology stacks
	JT_GlobalVariable("jSc_QS2_name",0,"slow framescan",1)			// Quick-setting identifier
	JT_GlobalVariable("jSc_QS2_nFrames",3,"",0)						// Number of frames to acquire during grab operations
	JT_GlobalVariable("jSc_QS2_averageFrames",1,"",0)				// Boolean: Average frames during grab operations?
	JT_GlobalVariable("jSc_QS2_burstFrames",0,"",0)					// Boolean: Burst frames mode during grab operations?
	JT_GlobalVariable("jSc_QS2_nBurstFrames",10,"",0)				// Number of frames in burstFrames mode
	JT_GlobalVariable("jSc_QS2_scanAngle",0,"",0)					// Scan angle (degrees)
	JT_GlobalVariable("jSc_QS2_mspl",2,"",0)						// Milliseconds per line
	JT_GlobalVariable("jSc_QS2_flyback",0.5,"",0)					// Time alotted for flyback in milliseconds
	JT_GlobalVariable("jSc_QS2_pixelBin",8,"",0)					// Binning of samples per pixel (this increases the effective sampling rate!)
	JT_GlobalVariable("jSc_QS2_pxpl",512,"",0)						// Number of pixels per line
	JT_GlobalVariable("jSc_QS2_lnpf",512,"",0)						// Number of lines per frame
	JT_GlobalVariable("jSc_QS2_xAmp",2,"",0)						// Scan amplitude (V), x axis
	JT_GlobalVariable("jSc_QS2_yAmp",2,"",0)						// Scan amplitude (V), y axis
	JT_GlobalVariable("jSc_QS2_xPad",0.05,"",0)						// Fast axis padding: this is how much the mirrors swing outside the FOV defined by xAmp & yAmp
	JT_GlobalVariable("jSc_QS2_ZoomFactor",1,"",0)					// Zoom factor
	JT_GlobalVariable("jSc_QS2_Ch1on",0,"",0)						// Boolean: Scan channel #1
	JT_GlobalVariable("jSc_QS2_Ch2on",1,"",0)						// Boolean: Scan channel #2
	JT_GlobalVariable("jSc_QS2_Ch3on",0,"",0)						// Boolean: Scan channel #3
	JT_GlobalVariable("jSc_QS2_imSize",250,"",0)					// Size of window showing the frames
	JT_GlobalVariable("jSc_QS2_vRange1",10,"",0)						// +/- input voltage range, channel #1 (V)
	JT_GlobalVariable("jSc_QS2_vRange2",10,"",0)						// +/- input voltage range, channel #2 (V)
	JT_GlobalVariable("jSc_QS2_vRange3",0.5,"",0)					// +/- input voltage range, channel #3 (V)
	JT_GlobalVariable("jSc_QS2_LUTstart1",0,"",0)					// LUT start, channel 1
	JT_GlobalVariable("jSc_QS2_LUTend1",500,"",0)					// LUT end, channel 1
	JT_GlobalVariable("jSc_QS2_LUTstart2",0,"",0)					// LUT start, channel 2
	JT_GlobalVariable("jSc_QS2_LUTend2",500,"",0)					// LUT end, channel 2
	JT_GlobalVariable("jSc_QS2_LUTstart3",0,"",0)					// LUT start, channel 3
	JT_GlobalVariable("jSc_QS2_LUTend3",500,"",0)					// LUT end, channel 3
	JT_GlobalVariable("jSc_QS2_LUTauto1",0,"",0)					// Boolean: LUT auto-scaled, channel 1?
	JT_GlobalVariable("jSc_QS2_LUTauto2",0,"",0)					// Boolean: LUT auto-scaled, channel 2?
	JT_GlobalVariable("jSc_QS2_LUTauto3",1,"",0)					// Boolean: LUT auto-scaled, channel 3?
	JT_GlobalVariable("jSc_QS2_LSflag",0,"",0)						// Boolean: Linescan?
	printf "\r"

	// Default Quick Settings #3 -- fast linescans
	JT_GlobalVariable("jSc_QS3_name",0,"linescan",1)				// Quick-setting identifier
	JT_GlobalVariable("jSc_QS3_nFrames",1,"",0)						// Number of frames to acquire during grab operations
	JT_GlobalVariable("jSc_QS3_averageFrames",0,"",0)				// Boolean: Average frames during grab operations?
	JT_GlobalVariable("jSc_QS3_burstFrames",0,"",0)					// Boolean: Burst frames mode during grab operations?
	JT_GlobalVariable("jSc_QS3_nBurstFrames",10,"",0)				// Number of frames in burstFrames mode
	JT_GlobalVariable("jSc_QS3_scanAngle",0,"",0)					// Scan angle (degrees)
	JT_GlobalVariable("jSc_QS3_mspl",8,"",0)						// Milliseconds per line
	JT_GlobalVariable("jSc_QS3_flyback",2,"",0)						// Time alotted for flyback in milliseconds
	JT_GlobalVariable("jSc_QS3_pixelBin",8,"",0)					// Binning of samples per pixel (this increases the effective sampling rate!)
	JT_GlobalVariable("jSc_QS3_pxpl",256,"",0)						// Number of pixels per line
	JT_GlobalVariable("jSc_QS3_lnpf",512,"",0)						// Number of lines per frame
	JT_GlobalVariable("jSc_QS3_xAmp",2,"",0)						// Scan amplitude (V), x axis
	JT_GlobalVariable("jSc_QS3_yAmp",2,"",0)						// Scan amplitude (V), y axis
	JT_GlobalVariable("jSc_QS3_xPad",0.05,"",0)						// Fast axis padding: this is how much the mirrors swing outside the FOV defined by xAmp & yAmp
	JT_GlobalVariable("jSc_QS3_ZoomFactor",1,"",0)					// Zoom factor
	JT_GlobalVariable("jSc_QS3_Ch1on",1,"",0)						// Boolean: Scan channel #1
	JT_GlobalVariable("jSc_QS3_Ch2on",1,"",0)						// Boolean: Scan channel #2
	JT_GlobalVariable("jSc_QS3_Ch3on",0,"",0)						// Boolean: Scan channel #3
	JT_GlobalVariable("jSc_QS3_imSize",250,"",0)					// Size of window showing the frames
	JT_GlobalVariable("jSc_QS3_vRange1",10,"",0)						// +/- input voltage range, channel #1 (V)
	JT_GlobalVariable("jSc_QS3_vRange2",10,"",0)						// +/- input voltage range, channel #2 (V)
	JT_GlobalVariable("jSc_QS3_vRange3",0.5,"",0)					// +/- input voltage range, channel #3 (V)
	JT_GlobalVariable("jSc_QS3_LUTstart1",0,"",0)					// LUT start, channel 1
	JT_GlobalVariable("jSc_QS3_LUTend1",500,"",0)					// LUT end, channel 1
	JT_GlobalVariable("jSc_QS3_LUTstart2",0,"",0)					// LUT start, channel 2
	JT_GlobalVariable("jSc_QS3_LUTend2",500,"",0)					// LUT end, channel 2
	JT_GlobalVariable("jSc_QS3_LUTstart3",0,"",0)					// LUT start, channel 3
	JT_GlobalVariable("jSc_QS3_LUTend3",500,"",0)					// LUT end, channel 3
	JT_GlobalVariable("jSc_QS3_LUTauto1",0,"",0)					// Boolean: LUT auto-scaled, channel 1?
	JT_GlobalVariable("jSc_QS3_LUTauto2",0,"",0)					// Boolean: LUT auto-scaled, channel 2?
	JT_GlobalVariable("jSc_QS3_LUTauto3",1,"",0)					// Boolean: LUT auto-scaled, channel 3?
	JT_GlobalVariable("jSc_QS3_LSflag",1,"",0)						// Boolean: Linescan?
	printf "\r"
	
	// Quick Settings -- General parameters
	JT_GlobalVariable("jSc_nQS",3,"",0)								// Total number of Quick Settings
	String/G		jSc_QS_pList = ""								// List of parameters in each Quick Setting
	jSc_QS_pList += "nFrames;"
	jSc_QS_pList += "averageFrames;"
	jSc_QS_pList += "burstFrames;"
	jSc_QS_pList += "nBurstFrames;"
	jSc_QS_pList += "scanAngle;"
	jSc_QS_pList += "mspl;"
	jSc_QS_pList += "flyback;"
	jSc_QS_pList += "pixelBin;"
	jSc_QS_pList += "pxpl;"
	jSc_QS_pList += "lnpf;"
	jSc_QS_pList += "xAmp;"
	jSc_QS_pList += "yAmp;"
	jSc_QS_pList += "xPad;"
	jSc_QS_pList += "ZoomFactor;"
	jSc_QS_pList += "Ch1on;"
	jSc_QS_pList += "Ch2on;"
	jSc_QS_pList += "Ch3on;"
	jSc_QS_pList += "imSize;"
	jSc_QS_pList += "vRange1;"
	jSc_QS_pList += "vRange2;"
	jSc_QS_pList += "vRange3;"
	jSc_QS_pList += "LUTstart1;"
	jSc_QS_pList += "LUTend1;"
	jSc_QS_pList += "LUTstart2;"
	jSc_QS_pList += "LUTend2;"
	jSc_QS_pList += "LUTstart3;"
	jSc_QS_pList += "LUTend3;"
	jSc_QS_pList += "LUTauto1;"
	jSc_QS_pList += "LUTauto2;"
	jSc_QS_pList += "LUTauto3;"
	jSc_QS_pList += "LSflag;"

	// Stack parameters
	JT_GlobalVariable("jSc_stkStart",NaN,"",0)						// Start of a stack, z axis (µm)
	JT_GlobalVariable("jSc_stkEnd",NaN,"",0)						// End of a stack, z axis (µm)
	JT_GlobalVariable("jSc_stkSliceSpacing",1,"",0)					// Slice spacing in a stack (µm)
	JT_GlobalVariable("jSc_sliceCounter",0,"",0)					// Counts slices during grabStack operation
	JT_GlobalVariable("jSc_nSlices",0,"",0)							// Total number of slices during grabStack operation
	JT_GlobalVariable("jSc_GrabStackFlag",0,"",0)					// Boolean: Now grabbing stack?
	JT_GlobalVariable("jSc_ETLstack",0,"",0)						// Boolean: ETL stack or regular Com-port stack?
	JT_GlobalVariable("jSc_ETL_store",NaN,"",0)						// Stored ETL position (µm)

	// Stage communication parameters
	JT_GlobalVariable("jSc_stgX",10000,"",0)						// Stage x position (µm)
	JT_GlobalVariable("jSc_stgY",10000,"",0)						// Stage y position (µm)
	JT_GlobalVariable("jSc_stgZ",10000,"",0)						// Stage z position (µm)
	JT_GlobalVariable("jSc_stgX_store",10000,"",0)					// Stored stage x position (µm)
	JT_GlobalVariable("jSc_stgY_store",10000,"",0)					// Stored stage y position (µm)
	JT_GlobalVariable("jSc_stgZ_store",10000,"",0)					// Stored stage z position (µm)
	JT_GlobalVariable("jSc_comPort",0,"COM11",1)					// COM port for XYZ stage (No colon at the end!!!)

	// Uncaging parameters
	JT_GlobalVariable("jSc_stimFlag",0,"",0)							// Boolean: Running stimulation right now?
	JT_GlobalVariable("jSc_stim2pZapFlag",0,"",0)						// Boolean: Stimulation is 2p zap?
	JT_GlobalVariable("jSc_stim_xSize",8,"",0)							// Uncaging grid size, x
	JT_GlobalVariable("jSc_stim_ySize",8,"",0)							// Uncaging grid size, y
	JT_GlobalVariable("jSc_stim_mustRerandom",1,"",0)					// Boolean: Must rerandomize data e.g. when the grid size is adjusted
	JT_GlobalVariable("jSc_unc_gap",2,"",0)								// For pseudorandom uncaging pattern, this is the grid-sized gap required between last point uncaged
	JT_GlobalVariable("jSc_stim_dwellTime",195,"",0)					// Dwell time per uncaging point (ms)
	JT_GlobalVariable("jSc_stim_shutterTime",7,"",0)					// Shutter opening time per uncaging point (ms)
	JT_GlobalVariable("jSc_stim_shutterOpen",0,"",0)					// Shutter open value (V)
	JT_GlobalVariable("jSc_stim_shutterClosed",-2,"",0)					// Shutter closed value (V)
	JT_GlobalVariable("jSc_stim_nPulses",3,"",0)						// Number of shutter openings per uncaging point
	JT_GlobalVariable("jSc_stim_PulsePrePad",50,"",0)					// Padding before start of uncaging pulse (ms)
	JT_GlobalVariable("jSc_stim_freq",30,"",0)							// Frequency of those uncaging pulses (Hz)
	JT_GlobalVariable("jSc_unc_flyTime",5,"",0)							// Time spent flying between uncaging points
	JT_GlobalVariable("jSc_stim_sampFreq",40000,"",0)					// Sampling frequency for the uncaging sweeps (Hz) -- this should match that of MultiPatch software if used in parallel!
	JT_GlobalVariable("jSc_ProgTarget",15,"",0)							// For progress bar: target value
	JT_GlobalVariable("jSc_ProgVar",0,"",0)								// For progress bar: current value
	JT_GlobalVariable("jSc_ProgPeriod",0.6,"",0)						// For background task: Repetition period (s) -- this is how often the progress bar updates, for example
	JT_GlobalVariable("jSc_stimWait",10,"",0)							// When repeating uncaging pattern, wait this amount of time (s)
	JT_GlobalVariable("jSc_reRandomize",1,"",0)							// Boolean: When repeating uncaging pattern, rerandomize uncaging pattern between repeats?
	JT_GlobalVariable("jSc_stimRunCounter",1,"",0)						// Count the number of uncaging runs
	JT_GlobalVariable("jSc_maxStimRuns",4,"",0)							// Maximum number of uncaging runs
	JT_GlobalVariable("jSc_stim_Suffix",1,"",0)							// Uncaging suffix for saving files
	JT_GlobalVariable("jSc_deltaT1",0,"",0)								// Starting delta-T value for ephys current injections (ms)
	JT_GlobalVariable("jSc_deltaT2",0,"",0)								// Ending delta-T value for ephys current injections (ms)
	
	JT_GlobalVariable("jSc_noSpikeList",0,"<empty>",1)					// Boolean: List of postsyn current pulses to be ignored
	JT_GlobalVariable("jSc_addOffsetList",0,"<empty>",1)				// Boolean: List of pulses to be offset
	JT_GlobalVariable("jSc_spikeOffset",-20,"",0)						// When applying offset to postsyn current pulses, use this value (ms)

	JT_GlobalVariable("jSc_SpiralArc",5,"",0)							// Archimedean spiral: the constant arc length (in units of scanner control voltage mV)
	JT_GlobalVariable("jSc_SpiralSeparation",15,"",0)					// Archimedean spiral: the separation of the spiral arms (in units of scanner control voltage mV)
	JT_GlobalVariable("jSc_sendGate",1,"",0)							// Boolean: Send the gate signal or not?
	JT_GlobalVariable("jSc_GatePadStart",1.14875,"",0)					// Padding to account for shutter opening delay
	JT_GlobalVariable("jSc_GatePadEnd",0.16875,"",0)					// Padding to account for shutter closing delay
	JT_GlobalVariable("jSc_pickThreshold",0,"",0)						// Threshold for automatically picking cells
	JT_GlobalVariable("jSc_LS_pickSlice",0,"",0)						// Pick slice from recently loaded stack
	JT_GlobalVariable("jSc_minPixels",20,"",0)							// Minimum number of pixels for automatically picking cells
	JT_GlobalVariable("jSc_maxPixels",2000,"",0)						// Maximum number of pixels for automatically picking cells
	JT_GlobalVariable("jSc_staggerLastSpikeAcrossChannels",300,"",0)	// Stagger last spikes by this many (ms) across channels
	JT_GlobalVariable("jSc_padAfterLastSpike",200,"",0)					// Pad after last spike to enable more spacing of staggered last spikes
	
	Print " "		// JT_GlobalVariable uses printf
	
	jSc_loadSettings()
	jSc_parseSettings()
	Make_jScanPanel()
	jSc_initComPort()
	jSc_initBoard()
	jSc_closeShutter()
	jSc_applyQS(1)														// Quick Setting #1 --> default starting settings

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Load the settings file

Function jSc_loadSettings()

	NVAR		jSc_VerboseMode
 
 	Variable		refNum
	Open/P=Igor_Stuff/R refNum as "jScan_settings.txt"
	if (refNum == 0)
		Print "Could not load settings file."
		Abort "Could not load settings file."
	endif

	Print "Loading the settings file..."
	String/G		jSc_settingsStr = ""
	Variable		lineNumber
	Variable		len
	String		buffer
	lineNumber = 0
	do
		lineNumber += 1
		FReadLine refNum, buffer
		len = strlen(buffer)
		if (len == 0)
			break								// No more lines to be read
		endif
		if (jSc_VerboseMode)
			Printf "\tSettings file line number %d: %s\r", lineNumber, buffer[0,StrLen(Buffer)-2]
		endif
		jSc_settingsStr += buffer[0,StrLen(Buffer)-2]
		if (CmpStr(buffer[len-1],"\r") != 0)		// Last line has no CR ?
			Printf "\r"
		endif
	while (1)
	print "\tLoaded "+num2str(lineNumber)+" lines from the settings file."

	Close refNum
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Parse the settings string

Function jSc_parseSettings()

	SVAR		jSc_settingsStr
	NVAR		jSc_VerboseMode

	String	currLine
	String	currVar
	String	currVal
	Variable	n = ItemsInList(jSc_settingsStr)
	Variable	nSettingsParsed = 0
	Variable	i
	i = 0
	do
		currLine = StringFromList(i,jSc_settingsStr)
		currVar = StringFromList(0,currLine,":")
		currVal = StringFromList(1,currLine,":")
		if (Exists(currVar)==2)
			nSettingsParsed += 1
			SVAR/Z	str = $(currVar)
			if (SVAR_Exists(str))
				if (jSc_VerboseMode)
					print "String exists: \""+currVar+"\", to be set to \""+currVal+"\""
				endif
				str = currVal
			else
				if (jSc_VerboseMode)
					print "Variable exists: \""+currVar+"\", to be set to "+currVal
				endif
				NVAR	var = $(currVar)
				var = str2num(currVal)
			endif
		else
			if (jSc_VerboseMode)
				print "Not found: \""+currVar+"\", to be set to "+currVal
			endif
		endif
		i += 1
	while(i<n)
	print "\tParsed "+num2str(nSettingsParsed)+" settings."

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Obsolete code for parsing settings file.

Function jSc_key2setting(varStr,strFlag)
	String		varStr
	Variable		strFlag
	
	SVAR		jSc_settingsStr
	Variable		i1 = strSearch(jSc_settingsStr, varStr,0)
	Variable		i2 = strSearch(jSc_settingsStr,":",i1)+1
	Variable		i3 = strSearch(jSc_settingsStr,";",i2)-1

	if (strFlag)
		SVAR	str = $varStr
		str = jSc_settingsStr[i2,i3]
	else
		NVAR	var = $varStr
		var = str2num(jSc_settingsStr[i2,i3])
	endif

	print "\t"+jSc_settingsStr[i2,i3],"-->",varStr//,i1,i2,i3

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Rotate the scanning coordinates

Function jSc_Rotate(rotAngle,xCoord,yCoord)
	Variable		rotAngle
	
	WAVE		xCoord
	WAVE		yCoord

	Variable		radAngle = rotAngle*pi/180
	Variable		nPoints = numpnts(xCoord)

	Make/O/N=(nPoints,2) xxyy,xxyy2
	xxyy[0,nPoints-1][0] = xCoord[p]
	xxyy[0,nPoints-1][1] = yCoord[p]
	
	Make/O/N=(2,2) rotMat
	
	rotMat[0][0] = cos(radAngle)
	rotMat[0][1] = -sin(radAngle)
	rotMat[1][0] = sin(radAngle)
	rotMat[1][1] = cos(radAngle)
	
	MatrixOP/O xxyy2 = rotMat x xxyy^t
	
	xCoord[0,nPoints-1] =xxyy2[0][p]
	yCoord[0,nPoints-1] =xxyy2[1][p]

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Init com port

Function jSc_initComPort()

	SVAR		jSc_comPort

	NVAR		jSc_stgZ
	NVAR		jSc_stkStart
	NVAR		jSc_stkEnd
	NVAR		jSc_nSlices
	
	VDTGetPortList2
	String		AvailablePortsList = S_VDT
	Print "On this computer, located "+num2str(ItemsInList(AvailablePortsList))+" serial ports:",AvailablePortsList

#ifdef DemoMode
	print "\t\tDemoMode: jSc_initComPort simulated"
#else
	if (FindListItem(jSc_comPort,AvailablePortsList)==-1)
		print "Fatal error! "+jSc_comPort+" does not exist on this computer."
		Abort "Fatal error! "+jSc_comPort+" does not exist on this computer."
	else
		print "COM port for XYZ stage is "+jSc_comPort
	endif
#endif

	Variable/G	jSc_COM_TimeOut = 3				// Time-out in seconds for VDT2 commands.
	String/G	jSc_COM_TermStr = "\r"			// The termination character used for communication with Scientifica boxes is CR
	Variable/G	jSc_COM_OpenClosePorts = 1		// Boolean: Open and close ports after each serial port command? True = safer but slower, false = faster but less reliable
	Variable/G	jSc_COM_Scaling = 10			// Scale coordinate values by 10?
	
	String		testStr
	do
		testStr = jSc_COM_SendStr("date")
		if (StrLen(testStr)>0)
			print "\t"+jSc_comPort+" seems to be working fine."
		else
			doAlert 1,"There appears to be a problem with "+jSc_comPort+". Did you forget to turn on the controller box? If so, turn it on and click Yes to try again."
			if (V_flag==2)
				Abort
			endif
		endif
	while (StrLen(testStr)==0)
	jSc_COM_getPos()
	jSc_stkStart = Round(jSc_stgZ)				// Set stack start and stack end to reasonable values, to avoid crashing objective into something
	jSc_stkEnd = Round(jSc_stgZ)
	jSc_nSlices = 0

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Wait until move has completed

Function jSc_COM_WaitUntilMoveDone()

	NVAR		jSc_COM_TimeOut
	SVAR		jSc_COM_TermStr
	
	NVAR		jSc_VerboseMode
	NVAR		jSc_COM_OpenClosePorts
	
	SVAR		jSc_comPort
	
	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ
	NVAR		jSc_COM_Scaling

	Variable		ReadVal
	Variable		i
	
#ifdef DemoMode
	print "\t\tDemoMode: jSc_COM_WaitUntilMoveDone simulated"
#else
	if (jSc_COM_OpenClosePorts)
		VDTOpenPort2 $jSc_comPort
	endif
	VDTOperationsPort2 $jSc_comPort
	do
		// Note to self: No, I *cannot* call jSc_COM_getPos instead here, because if jSc_COM_OpenClosePorts is True, 
		// then a possibly fatal bug will result. So I have to explicitly reproduce the XYZ coordinate read here again.
		VDTWrite2/O=(jSc_COM_TimeOut) "px\r"
		VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadVal
		jSc_stgX = ReadVal/jSc_COM_Scaling
		VDTWrite2/O=(jSc_COM_TimeOut) "py\r"
		VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadVal
		jSc_stgY = ReadVal/jSc_COM_Scaling
		VDTWrite2/O=(jSc_COM_TimeOut) "pz\r"
		VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadVal
		jSc_stgZ = ReadVal/jSc_COM_Scaling
		VDTWrite2/O=(jSc_COM_TimeOut) "S\r"
		VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadVal
		if (jSc_VerboseMode)
			print "\t{jSc_COM_WaitUntilMoveDone} got ReadVal=",ReadVal," --- WAITING --- ("+num2str(jSc_stgX)+", "+num2str(jSc_stgY)+", "+num2str(jSc_stgZ)+")"
		endif
	while(ReadVal!=0)
	if (jSc_COM_OpenClosePorts)
		VDTClosePort2 $jSc_comPort
	endif
	if (jSc_VerboseMode)
		print "{jSc_COM_WaitUntilMoveDone} for XYZ stage using port",jSc_comPort
		print "\tGot ReadVal=",ReadVal
	endif
#endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Zero the coordinate system for the XYZ stage

Function jSc_COM_zero()

	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ
	NVAR		jSc_stkStart
	NVAR		jSc_stkEnd
	NVAR		jSc_nSlices
	
#ifdef DemoMode
	print "\t\tDemoMode: jSc_COM_zero simulated"
	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ
	jSc_stgX = 0
	jSc_stgY = 0
	jSc_stgZ = 0
#else
	print "--- Zeroing the XYZ stage coordinate system ---"
	print "Date:",Date()
	print "Time:",Time()
	jSc_COM_getPos()
	print "The coordinates ("+num2str(jSc_stgX)+","+num2str(jSc_stgY)+","+num2str(jSc_stgZ)+") are now (0,0,0)."
	jSc_COM_SendStr("zero")
	jSc_COM_getPos()
	jSc_stkStart = Round(jSc_stgZ)				// Set stack start and stack end to reasonable values, to avoid crashing objective into something
	jSc_stkEnd = Round(jSc_stgZ)
	jSc_nSlices = 0
#endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get position for one selected manipulator

Function jSc_COM_getPos()

	NVAR		jSc_COM_TimeOut
	SVAR		jSc_COM_TermStr
	
	NVAR		jSc_VerboseMode
	NVAR		jSc_COM_OpenClosePorts
	
	SVAR		jSc_comPort

	NVAR		jSc_COM_Scaling
	
	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ

	String		CurrPort,ReadStr
	Variable		ReadVal
	
#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: jSc_COM_getPos simulated"
	endif
	jSc_stgX = Round(eNoise(100))
	jSc_stgY = Round(eNoise(100))
	jSc_stgZ = Round(eNoise(100))
#else
	if (jSc_COM_OpenClosePorts)
		VDTOpenPort2 $jSc_comPort
	endif
	VDTOperationsPort2 $jSc_comPort
	VDTWrite2/O=(jSc_COM_TimeOut) "px\r"
	VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadVal
	jSc_stgX = ReadVal/jSc_COM_Scaling
	VDTWrite2/O=(jSc_COM_TimeOut) "py\r"
	VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadVal
	jSc_stgY = ReadVal/jSc_COM_Scaling
	VDTWrite2/O=(jSc_COM_TimeOut) "pz\r"
	VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadVal
	jSc_stgZ = ReadVal/jSc_COM_Scaling
	if (jSc_COM_OpenClosePorts)
		VDTClosePort2 $jSc_comPort
	endif
#endif

End

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move XYZ stage to desired position

Function jSc_COM_MoveTo(x,y,z)
	Variable		x
	Variable		y
	Variable		z

	NVAR		jSc_COM_TimeOut
	SVAR		jSc_COM_TermStr
	
	NVAR		jSc_VerboseMode
	NVAR		jSc_COM_OpenClosePorts
	
	SVAR		jSc_comPort

	NVAR		jSc_COM_Scaling

	String		ReadStr
	Variable		ReadVal
	
#ifdef DemoMode
	print "\t\tDemoMode: jSc_COM_MoveTo simulated"
#else
	if (jSc_COM_OpenClosePorts)
		VDTOpenPort2 $jSc_comPort
	endif
	VDTOperationsPort2 $jSc_comPort
	VDTWrite2/O=(jSc_COM_TimeOut) "ABS "+num2str(Round(x*jSc_COM_Scaling))+" "+num2str(Round(y*jSc_COM_Scaling))+" "+num2str(Round(z*jSc_COM_Scaling))+"\r"
	if (jSc_COM_OpenClosePorts)
		VDTClosePort2 $jSc_comPort
	endif
	if (jSc_VerboseMode)
		print "{jSc_COM_MoveTo} Moving stage using port",jSc_comPort,"and [x,y,z]=",Round(x),Round(y),Round(z)," with scaling ",jSc_COM_Scaling
	endif	
#endif	

End
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Send arbitrary string to XYZ stage

Function/S jSc_COM_SendStr(theString)
	String		theString

	NVAR		jSc_COM_TimeOut
	SVAR		jSc_COM_TermStr
	
	NVAR		jSc_VerboseMode
	NVAR		jSc_COM_OpenClosePorts
	
	SVAR		jSc_comPort
	String		ReadStr
	
#ifdef DemoMode
	print "\t\tDemoMode: jSc_COM_SendStr simulated"
	ReadStr = "Nonsense"
#else
	if (jSc_COM_OpenClosePorts)
		VDTOpenPort2 $jSc_comPort
	endif
	VDTOperationsPort2 $jSc_comPort
	VDTWrite2/O=(jSc_COM_TimeOut) theString+"\r"
	VDTRead2/O=(jSc_COM_TimeOut)/Q/T=(jSc_COM_TermStr) ReadStr
	if (jSc_COM_OpenClosePorts)
		VDTClosePort2 $jSc_comPort
	endif
	if (jSc_VerboseMode)
		print "{jSc_COM_SendStr} using port",jSc_comPort
	endif
#endif
	
	Return ReadStr

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Bring jScan to front, or start it up if it has not already been started up

Function jSc()

	DoWindow jScanPanel
	if (V_flag)
		jSc_im2front()
		DoWindow/F jScanPanel
	else
		init_jScan()
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Resize the image window

Function jSc_resizeImagesProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName

	jSc_drawImages()
	DoWindow/F jScanPanel
	 
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the image frames

Function jSc_makeFramesProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName

	 jSc_makeFrames()

End

Function jSc_makeFrames()

	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	
	Make/U/W/O/N=(jSc_pxpl,jSc_lnpf) ch1image,ch2image,ch3image

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the image frame stacks for burst-frames mode

Function jSc_makeBurstFramesProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable	varNum
	String		varStr
	String		varName

	 jSc_makeBurstFrames()

End

Function jSc_makeBurstFrames()

	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_nBurstFrames

	Make/U/W/O/N=(jSc_pxpl,jSc_lnpf,jSc_nBurstFrames) ch1imageBurst,ch2imageBurst,ch3imageBurst

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set the path string

Function jSc_SetPathProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			 jSc_DoSetPath()
			break
	endswitch

	return 0
End

Function jSc_DoSetPath()

	SVAR		jSc_PathStr
	String		dummyStr

	PathInfo jScPath
	if (V_flag)
		PathInfo/S jScPath												// Default to this path if it already exists
	endif
	NewPath/O/Q/M="Chose the path to save the experiment!" jScPath
	PathInfo jScPath
	if (V_flag)
		if (StrLen(S_path)>42+12)
			jSc_PathStr = S_path[0,12]+" ... "+S_path[strlen(S_path)-42,strlen(S_path)-1]
		else
			jSc_PathStr = S_path
		endif
		print "\t\""+S_path+"\""
	else
		print "ERROR! Path doesn't appear to exist!"
		jSc_PathStr = "<empty path>"
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Calculate total ms per line

Function jSc_calcTotMsplProc(sva) : SetVariableControl
	STRUCT		WMSetVariableAction &sva
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
			Variable dval = sva.dval
			String sval = sva.sval
			jSc_remakeScanIOdata()				// NOTE!
			jSc_calcTotMspl()
			break
		case 3: // Live update
	endswitch

	return 0
End

Function jSc_calcTotMspl()

	NVAR		jSc_mspl
	NVAR		jSc_flyback
	NVAR		jSc_totmspl
	
	jSc_totmspl = (jSc_mspl+jSc_flyback)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the jScan panel

Function Make_jScanPanel()

	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 32
	Variable		Ypos = 32
	Variable		Width = 420
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow jScanPanel
	if (V_flag)
		GetWindow jScanPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
	endif

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	Variable		plusSV = 1				// y-axis shift for SetVariables
	Variable		plusCheck = 3			// y-axis shift for CheckBoxes
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12

	DoWindow/K jScanPanel
#ifdef DemoMode
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "jScan Main Panel [DEMO MODE]"
#else
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "jScan Main Panel"
#endif
	DoWindow/C jScanPanel
	ModifyPanel/W=jScanPanel fixedSize=1
	
	//////////////////// Scanning stuff
	
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetDrawEnv fstyle= 5,fsize= 14,textyjust= 2
	DrawText x,y+5,"Main parameters"
	x += xSkip
	NVAR	jSc_nQS
	Variable	i
	i = 0
	do
		Button $("QS"+num2str(i+1)+"Button"),pos={x+2*xSkip/jSc_nQS*i,y},size={2*xSkip/jSc_nQS-4,bHeight},proc=jSc_QSProc,title="QS"+num2str(i+1),fsize=fontSize,font="Arial"
		i += 1
	while(i<jSc_nQS)
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	Button SetPathButton,pos={xMargin,y},size={64,bHeight},proc=jSc_SetPathProc,title="Set path",fsize=fontSize,font="Arial"
	SetVariable PathStrSetVar,frame=0,noedit=1,pos={xMargin+64+4,y+plusSV},size={Width-xMargin*2-64-4,bHeight},title=" ",value=jSc_PathStr,limits={0,0,0},fsize=fontSize,font="Arial"
	y += ySkip
	
	x = xMargin
	xSkip = floor((Width-xMargin*2)/3)
	SetVariable baseNameSV,pos={x,y+plusSV},size={xSkip*2-4,bHeight},title="basename: ",value=jSc_baseName,fsize=fontSize,font="Arial"
	x += xSkip
	x += xSkip
	SetVariable suffixSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="suffix: ",value=jSc_suffix,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	NVAR		jSc_max_xPad
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable msplSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="ms/line: ",proc=jSc_calcTotMsplProc,value=jSc_mspl,limits={0.5,Inf,0.5},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable flyBackSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="flyback (ms): ",proc=jSc_calcTotMsplProc,value=jSc_flyback,limits={0.2,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable padSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="x-pad: ",value=jSc_xPad,limits={0,Inf,jSc_max_xPad},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	NVAR		jSc_max_xAmp
	NVAR		jSc_max_yAmp
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable xAmpSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="xAmp (V): ",value=jSc_xAmp,limits={-jSc_max_xAmp,jSc_max_xAmp,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable yAmpSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="yAmp (V): ",value=jSc_yAmp,limits={-jSc_max_yAmp,jSc_max_yAmp,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable binningSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="binning:",value=jSc_pixelBin,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	SVAR		jSc_reportStr
	xSkip = floor((Width-xMargin*2)/1)
	x = xMargin
	SetVariable reportStrSV,styledText=1,textAlign=1,pos={x,y+plusSV},size={xSkip-4,bHeight},title=" ",value=jSc_reportStr,limits={1,Inf,0},fsize=fontSize,font="Arial",noedit=1,frame=0
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/4)
	x = xMargin
	Button Zoom1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_zoomProc,title="Zoom in",fsize=fontSize,font="Arial"
	x += xSkip
	Button Zoom2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_zoomProc,title="Zoom out",fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable zoomFactorSV,pos={x,y+plusSV},size={xSkip-4,bHeight},proc=jSc_remakeScanIOproc,title="zoom: ",value=jSc_ZoomFactor,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable scanAngleSV,pos={x,y+plusSV},size={xSkip-4,bHeight},proc=jSc_remakeScanIOproc,title="angle: ",value=jSc_scanAngle,limits={-Inf,Inf,15},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable pxplSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="pixels/line: ",proc=jSc_makeFramesProc,value=jSc_pxpl,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable lnpfSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="lines/frame: ",proc=jSc_makeFramesProc,value=jSc_lnpf,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable imszSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="image size: ",proc=jSc_resizeImagesProc,value=jSc_imSize,limits={50,Inf,50},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	NVAR		jSc_LSflag
	xSkip = floor((Width-xMargin*2)/4)
	x = xMargin+8
	CheckBox UseCh1Check,pos={x,y+plusCheck},title="channel 1",proc=jSc_readChBoxProc,value=jSc_Ch1on,fsize=fontSize,font="Arial"
	x += xSkip
	CheckBox UseCh2Check,pos={x,y+plusCheck},title="channel 2",proc=jSc_readChBoxProc,value=jSc_Ch2on,fsize=fontSize,font="Arial"
	x += xSkip
	CheckBox UseCh3Check,pos={x,y+plusCheck},title="channel 3",proc=jSc_readChBoxProc,value=jSc_Ch3on,fsize=fontSize,font="Arial"
	x += xSkip
	CheckBox LSCheck,pos={x,y+plusCheck},title="linescan",proc=jSc_readLSChBoxProc,value=jSc_LSflag,fsize=fontSize,font="Arial",help={"Collapse the y-axis scan amplitude yAmp to zero."}
	x += xSkip
	y += ySkip
	
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable vRange1SV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="input range 1: ",value=jSc_vRange1,limits={0.1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable vRange2SV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="input range 2: ",value=jSc_vRange2,limits={0.1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable vRange3SV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="input range 3: ",value=jSc_vRange3,limits={0.1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable nFramesSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="nFrames: ",value=jSc_nFrames,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable frameCounterSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="frame counter: ",value=jSc_frameCounter,limits={1,Inf,0},fsize=fontSize,font="Arial",noedit=1,frame=1
	x += xSkip
	SetVariable maxFramesSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="max nFrames: ",value=jSc_maxNFrames,limits={1,Inf,10},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	NVAR			jSc_burstFrames
	NVAR			jSc_averageFrames
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	CheckBox aveFramesCheck,pos={x,y+plusCheck},title="average frames",proc=jSc_readAveChBoxProc,value=jSc_averageFrames,fsize=fontSize,font="Arial",help={"Average nFrames number of frames, storing the average,\rand discarding the individual frames.\rN.B.! Does _not_ average the burst frames."}
	x += xSkip
	CheckBox burstFramesCheck,pos={x,y+plusCheck},title="burst frames",proc=jSc_readBurstChBoxProc,value=jSc_burstFrames,fsize=fontSize,font="Arial",help={"Acquire nBurstFrames number of frames rapidly,\ronly processing them at the end."}
	x += xSkip
	SetVariable nBurstsSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="nBurstFrames: ",value=jSc_nBurstFrames,proc=jSc_makeBurstFramesProc,limits={2,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable nLoopsSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="nLoops: ",value=jSc_nLoops,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable loopCounterSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="loop counter: ",value=jSc_loopCounter,limits={1,Inf,0},fsize=fontSize,font="Arial",noedit=1,frame=1
	x += xSkip
	SetVariable loopIntervalSV,pos={x,y+plusSV},size={xSkip-4,bHeight},title="loop period (s): ",value=jSc_loopPeriod,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button ScanButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_scanProc,title="Scan",fsize=fontSize,font="Arial",fColor=(0,65535,0),help={"Scan and view the sample.\rDoes not store any data."}
	x += xSkip
	Button GrabButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_grabProc,title="Grab",fsize=fontSize,font="Arial",fColor=(0,0,65535),help={"Grab once and store."}
	x += xSkip
	Button LoopButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_loopRunProc,title="Loop",fsize=fontSize,font="Arial",fColor=(65535,0,65535),help={"Grab nLoops number of times,\rspaced by loop period,\rstoring the acquired data."}
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button Im1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_manageImagesProc,title="Images to front",fsize=fontSize,font="Arial"
	x += xSkip
	Button Im2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_manageImagesProc,title="Images to back",fsize=fontSize,font="Arial"
	x += xSkip
	Button Im3Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_manageImagesProc,title="Kill images",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	SetDrawLayer UserFront
	SetDrawEnv linethick= 2
	DrawLine xMargin,y,Width-xMargin*2,y
	y += ySkip-bHeight
	
	//////////////////// XYZ Position
	
	Variable specialMargin = 45
	Variable	grayVal = 0.9
	xSkip = floor((Width-specialMargin-xMargin*2)/5)
	x = xMargin
	SetDrawEnv fstyle= 5,fsize= 14,textyjust= 2
	DrawText x,y+5,"Stage"

	x = xMargin+specialMargin
	SetVariable xPosSV,pos={x,y+3},size={xSkip-4,bHeight},title="x",value=jSc_stgX,limits={-Inf,Inf,0},fsize=fontSize,font="Arial",noedit=1,valueBackColor=(65535*grayVal,65535*grayVal,65535*grayVal)//,frame=0
	x += xSkip
	SetVariable yPosSV,pos={x,y+3},size={xSkip-4,bHeight},title="y",value=jSc_stgY,limits={-Inf,Inf,0},fsize=fontSize,font="Arial",noedit=1,valueBackColor=(65535*grayVal,65535*grayVal,65535*grayVal)//,frame=0
	x += xSkip
	SetVariable zPosSV,pos={x,y+3},size={xSkip-4,bHeight},title="z",value=jSc_stgZ,limits={-Inf,Inf,0},fsize=fontSize,font="Arial",noedit=1,valueBackColor=(65535*grayVal,65535*grayVal,65535*grayVal)//,frame=0
	x += xSkip
	Button zeroStageButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_stgZeroProc,title="XYZ=0",fsize=fontSize,font="Arial"
	x += xSkip
	Button getPosButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_stgUpdateProc,title="Update",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip
	
	//////////////////// ETL parameters
	
	NVAR	jSc_ETLexists
	if (jSc_ETLexists)
		NVAR	jSc_ETLcommand
		NVAR	jSc_ETLmin
		NVAR	jSc_ETLmax
		NVAR	jSc_ETLmicron
		xSkip = floor((Width-specialMargin-xMargin*2)/3)
		x = xMargin
		SetDrawEnv fstyle= 5,fsize= 14,textyjust= 2
		DrawText x,y+5,"ETL"
		x = xMargin+specialMargin
	 	Slider ETLslider,pos={x,y+5},size={xSkip-4,bHeight},ticks=0,vert=0,variable=jSc_ETLcommand,limits={jSc_ETLmin,jSc_ETLmax,0.1},side=0,proc=ETLsliderProc,fsize=fontSize,font="Arial"
		x += xSkip
		SetVariable ETLcommandSV,pos={x,y+3},size={xSkip*1.2-4,bHeight},title="Command [V]: ",value=jSc_ETLcommand,proc=ETLSetVarProc,limits={jSc_ETLmin,jSc_ETLmax,0.1},fsize=fontSize,font="Arial"
		x += xSkip*1.2
		// This mess is because minimum ETL voltage may result in maximum µm depending on sign of V-to-µm scaling factor
		variable highEnd = max(jSc_ETLtoMicron(jSc_ETLmin),jSc_ETLtoMicron(jSc_ETLmax))
		variable lowEnd = min(jSc_ETLtoMicron(jSc_ETLmin),jSc_ETLtoMicron(jSc_ETLmax))
		SetVariable ETLmicronsSV,pos={x,y+3},size={xSkip*0.8-4,bHeight},title="in µm: ",value=jSc_ETLmicron,proc=ETLmicronSetVarProc,limits={lowEnd,highEnd,1},fsize=fontSize,font="Arial"
		x += xSkip
		y += ySkip
	endif

	SetDrawLayer UserFront
	SetDrawEnv linethick= 2
	DrawLine xMargin,y,Width-xMargin*2,y
	y += ySkip-bHeight
	
	//////////////////// General stuff
	
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button makeUncPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_makeUncPanelProc,title="Make uncaging panel",fsize=fontSize,font="Arial"
	x += xSkip
	Button makeStackPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_makeStackPanelProc,title="Make stack panel",fsize=fontSize,font="Arial"
	x += xSkip
	Button make2pZapPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_make2pZapPanelProc,title="Make 2p zap panel",fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button shutter1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_shutterProc,title="Open mech shutter",fsize=fontSize,font="Arial"
	x += xSkip
	Button shutter2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_shutterProc,title="Close mech shutter",fsize=fontSize,font="Arial"
	x += xSkip
	DoWindow MultiPatch_Switchboard
	if (V_flag)
		Button goToMultiPatchButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_goToMPProc,title="Go to MultiPatch",fsize=fontSize,font="Arial"
	else
		Button goToMultiPatchButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_goToMPProc,title="Go to MultiPatch",fsize=fontSize,font="Arial",disable=2
	endif
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button GalvoShutter1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_galvoShutterProc,title="Open galvo shutter",fsize=fontSize,font="Arial"
	x += xSkip
	Button GalvoShutter2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_galvoShutterProc,title="Close galvo shutter",fsize=fontSize,font="Arial"
	x += xSkip
	Button resetBoardButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_resetBoardProc,title="Reset board",fsize=fontSize,font="Arial",fColor=(65535,0,0)
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button RedrawImagesButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_RedrawImagesProc,title="Redraw images",fsize=fontSize,font="Arial"
	x += xSkip
	Button RedrawPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_RedrawPanelProc,title="Redraw panel",fsize=fontSize,font="Arial"
	x += xSkip
	Button ReInitButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_ReInitProc,title="Re-init jScan",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	MoveWindow/W=jScanPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...
	
	jSc_calcTotMspl()
	jSc_makeFrames()
	jSc_makeBurstFrames()			// Not really necessary to execute here, but by symmetry with the above line
	jSc_drawImages()
	
	DoWindow/F jScanPanel

End

/////////////////////////////////////////////////////////////////////////
// ETL slider

Function ETLsliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa
	
	NVAR		jSc_ETLcommand
	NVAR		jSc_ETLmicron

	switch( sa.eventCode )
		case -1: // kill
			break
		default:
			if( sa.eventCode & 2^0 ) // value set -- set ETL command
				jSc_ETLmicron = jSc_ETLtoMicron(jSc_ETLcommand)
				jSc_updateETLcommand()
			endif
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////
// ETL SetVar

Function ETLSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	NVAR		jSc_ETLmin
	NVAR		jSc_ETLmax

	NVAR		jSc_ETLcommand
	NVAR		jSc_ETLmicron

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			jSc_ETLcommand= limit(jSc_ETLcommand,jSc_ETLmin,jSc_ETLmax)		// Ensure ETL voltage is within bounds
			jSc_ETLmicron = jSc_ETLtoMicron(jSc_ETLcommand)
			jSc_updateETLcommand()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////
// ETL Micron SetVar

Function ETLmicronSetVarProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	NVAR	jSc_ETLcommand
	NVAR	jSc_ETLmicron
	
	NVAR	jSc_ETLmin
	NVAR	jSc_ETLmax

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			// This mess is because minimum ETL voltage may result in maximum µm depending on sign of V-to-µm scaling factor
			variable highEnd = max(jSc_ETLtoMicron(jSc_ETLmin),jSc_ETLtoMicron(jSc_ETLmax))
			variable lowEnd = min(jSc_ETLtoMicron(jSc_ETLmin),jSc_ETLtoMicron(jSc_ETLmax))
			jSc_ETLmicron = limit(jSc_ETLmicron,lowEnd,highEnd)			// Ensure ETL focus in µm is within range
			jSc_ETLcommand = jSc_MicronToETL(jSc_ETLmicron)
			jSc_updateETLcommand()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Rescale ETL to µm
//// Be careful with the sign: voltages smaller than offset (e.g. 2V < 5V offset) means deeper into slice

Function jSc_ETLtoMicron(theCommand)
	Variable	theCommand
	
	NVAR	jSc_ETLoffset
	NVAR	jSc_ETLscaling
	
	Variable theMicron

	theMicron = -(theCommand-jSc_ETLoffset)*jSc_ETLscaling
	
	Return theMicron

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Rescale ETL to µm
//// Be careful with the sign: voltages smaller than offset (e.g. 2V < 5V offset) means deeper into slice

Function jSc_MicronToETL(theMicron)
	Variable theMicron

	NVAR	jSc_ETLoffset
	NVAR	jSc_ETLscaling
	
	Variable	theCommand
	
	theCommand = -theMicron/jSc_ETLscaling+jSc_ETLoffset
	
	Return theCommand

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the jStack panel

Function jSc_updateETLcommand()
	SVAR		jSc_ETLDevStr
	NVAR		jSc_ETLout
	NVAR		jSc_ETLcommand
	NVAR		jSc_ETLmin
	NVAR		jSc_ETLmax
	
	if ( (jSc_ETLcommand>jSc_ETLmax) %| (jSc_ETLcommand<jSc_ETLmin))
		print "ETL command = "+num2str(jSc_ETLcommand)+" is outside the range allowed: ["+num2str(jSc_ETLmin)+","+num2str(jSc_ETLmax)+"]."
		abort "ETL command = "+num2str(jSc_ETLcommand)+" is outside the range allowed: ["+num2str(jSc_ETLmin)+","+num2str(jSc_ETLmax)+"]."
	endif

#ifdef DemoMode
	print "\t\tDemoMode: jSc_updateETLcommand simulated for "+num2str(jSc_ETLcommand)
#else
	fDAQmx_WriteChan(jSc_ETLDevStr,jSc_ETLout,jSc_ETLcommand,jSc_ETLmin,jSc_ETLmax)
#endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the jStack panel

Function jSc_goToMPProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoWindow/F MultiPatch_Switchboard
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the jStack panel

Function jSc_makeStackPanelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Make_jStackPanel()
			break
	endswitch

	return 0
End

Function Make_jStackPanel()

	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 150
	Variable		Ypos = 128
	Variable		Width = 420
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow jStackPanel
	if (V_flag)
		GetWindow jStackPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
	endif

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12
	
	NVAR			jSc_ETLexists
	NVAR			jSc_ETLstack

	DoWindow/K jStackPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "jScan Stack Acquisition Panel"
	DoWindow/C jStackPanel
	ModifyPanel/W=jStackPanel fixedSize=1
	
	//////////////////// Stack acquisition stuff
	
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetDrawEnv fstyle= 5,fsize= 14,textyjust= 2
	DrawText x,y+5,"Stack parameters"
	x += xSkip
	x += xSkip
	CheckBox ETLstackCheck,pos={x,y+3},title="ETL stack?",value=jSc_ETLstack,proc=ETLstackCheckProc,fsize=fontSize,font="Arial"		// Acquire stack with ETL or with stage?
	if (jSc_ETLexists==0)		// Disable ETL stack if no ETL is installed.
		jSc_ETLstack = 0
		CheckBox ETLstackCheck,disable=2,win=jStackPanel
	endif
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable stackStartSV,pos={x,y+3},size={xSkip-4,bHeight},title="stack start: ",value=jSc_stkStart,limits={-Inf,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable stackEndSV,pos={x,y+3},size={xSkip-4,bHeight},title="stack end: ",value=jSc_stkEnd,limits={-Inf,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable sliceSpacingSV,pos={x,y+3},size={xSkip-4,bHeight},title="spacing: ",value=jSc_stkSliceSpacing,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button stackPos1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_stkPosProc,title="Set stack start",fsize=fontSize,font="Arial"//,fColor=(0,65535,0)
	x += xSkip
	Button stackPos2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_stkPosProc,title="Set stack end",fsize=fontSize,font="Arial"//,fColor=(0,0,65535)
	x += xSkip
	Button grabStackButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_grabStackProc,title="Acquire stack",fsize=fontSize,font="Arial",fColor=(0,0,65535)
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable sliceCounterSV,pos={x,y+3},size={xSkip-4,bHeight},title="slice counter: ",value=jSc_sliceCounter,limits={-Inf,Inf,0},fsize=fontSize,font="Arial",noEdit=1,frame=0
	x += xSkip
	SetVariable nSlicesSV,pos={x,y+3},size={xSkip-4,bHeight},title="nSlices: ",value=jSc_nSlices,limits={2,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	Button closeUncPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=JT_WinCloseProc,title="Close panel",fsize=fontSize,font="Arial",fColor=(65535,0,0)
	x += xSkip
	y += ySkip

	SetDrawLayer UserFront
	SetDrawEnv linethick= 2
	DrawLine xMargin,y,Width-xMargin*2,y
	y += ySkip-bHeight

	Variable specialMargin = 45

	NVAR	jSc_ETLexists
	if (jSc_ETLexists)
		NVAR	jSc_ETLcommand
		NVAR	jSc_ETLmin
		NVAR	jSc_ETLmax
		NVAR	jSc_ETLmicron
		xSkip = floor((Width-specialMargin-xMargin*2)/3)
		x = xMargin
		SetDrawEnv fstyle= 5,fsize= 14,textyjust= 2
		DrawText x,y+5,"ETL"
		x = xMargin+specialMargin
	 	Slider ETLslider,pos={x,y+5},size={xSkip-4,bHeight},ticks=0,vert=0,variable=jSc_ETLcommand,limits={jSc_ETLmin,jSc_ETLmax,0.1},side=0,proc=ETLsliderProc,fsize=fontSize,font="Arial"
		x += xSkip
		SetVariable ETLcommandSV,pos={x,y+3},size={xSkip*1.2-4,bHeight},title="Command [V]: ",value=jSc_ETLcommand,proc=ETLSetVarProc,limits={jSc_ETLmin,jSc_ETLmax,0.1},fsize=fontSize,font="Arial"
		x += xSkip*1.2
		variable highEnd = max(jSc_ETLtoMicron(jSc_ETLmin),jSc_ETLtoMicron(jSc_ETLmax))
		variable lowEnd = min(jSc_ETLtoMicron(jSc_ETLmin),jSc_ETLtoMicron(jSc_ETLmax))
		SetVariable ETLmicronsSV,pos={x,y+3},size={xSkip*0.8-4,bHeight},title="in µm: ",value=jSc_ETLmicron,proc=ETLmicronSetVarProc,limits={lowEnd,highEnd,1},fsize=fontSize,font="Arial"
		x += xSkip
		y += ySkip
	endif

	MoveWindow/W=jStackPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// ETL stack checkbox

Function ETLstackCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	NVAR			jSc_ETLstack
	
	NVAR			jSc_stkStart
	NVAR			jSc_stkEnd
	NVAR			jSc_nSlices
	
	NVAR			jSc_stgZ
	
	NVAR			jSc_ETLoffset

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			jSc_ETLstack = checked
			if (jSc_ETLstack)
				print Time()," -- ETL stack checked."
				jSc_stkStart = 0						// Set stack start and stack end to reasonable values
				jSc_stkEnd = 0
				jSc_nSlices = 0
			else
				jSc_COM_getPos()
				jSc_stkStart = Round(jSc_stgZ)			// Set stack start and stack end to reasonable values, to avoid crashing objective into something
				jSc_stkEnd = Round(jSc_stgZ)
				jSc_nSlices = 0
				print Time()," -- ETL stack unchecked."
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the 2p zap panel

Function jSc_make2pZapPanelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Make_j2pZapPanel()
			break
	endswitch

	return 0
End

Function Make_j2pZapPanel()

	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 460
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow j2pZapPanel
	if (V_flag)
		GetWindow j2pZapPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
	endif
	
	NVAR			jSc_sendGate

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12

	DoWindow/K j2pZapPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "2p Zap Panel"
	DoWindow/C j2pZapPanel
	ModifyPanel/W=j2pZapPanel fixedSize=1
	
	//////////////////// 2p zap stuff
	
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetDrawEnv fstyle= 5,fsize= 14,textyjust= 2
	DrawText x,y+5,"2p zap parameters"
	x += xSkip
	PopupMenu PickPicPop,pos={x,y},size={xSkip-4,bHeight},bodyWidth=(xSkip-4),proc=jSc_PickChannelProc,title="Pick source",font="Arial",fSize=fontSize
	PopupMenu PickPicPop,mode=0,value="Channel 1;Channel 2;Channel 3;Ch 1 stack;Ch 2 stack;Ch 3 stack;"
	x += xSkip
	SetVariable unc_sampFreqSV,pos={x,y+3},size={xSkip-4,bHeight},title="samp freq (Hz): ",value=jSc_stim_sampFreq,limits={500,Inf,500},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable flySV,pos={x,y+3},size={xSkip-4,bHeight},title="fly (ms): ",value=jSc_unc_flyTime,limits={0.1,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable dwellSV,pos={x,y+3},size={xSkip-4,bHeight},title="dwell (ms): ",value=jSc_stim_dwellTime,limits={100,Inf,100},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable shutterSV,pos={x,y+3},size={xSkip-4,bHeight},title="open (ms): ",value=jSc_stim_shutterTime,limits={0.1,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable stimPulsePrePadSV,pos={x,y+3},size={xSkip-4,bHeight},title="prepad (ms): ",value=jSc_stim_PulsePrePad,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable stimnPulsesSV,pos={x,y+3},size={xSkip-4,bHeight},title="# of pulses: ",value=jSc_stim_nPulses,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable uncFreqSV,pos={x,y+3},size={xSkip-4,bHeight},title="frequency (Hz): ",value=jSc_stim_freq,limits={1,Inf,10},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable shutterClosedValSV,pos={x,y+3},size={xSkip-4,bHeight},title="gate closed (V): ",value=jSc_stim_shutterClosed,limits={-Inf,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable shutterOpenValSV,pos={x,y+3},size={xSkip-4,bHeight},title="gate open (V): ",value=jSc_stim_shutterOpen,limits={-Inf,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	CheckBox sendGateCheck,pos={x,y+3},title="send gate signal?",value=jSc_sendGate,fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable shutterPrePadSV,pos={x,y+3},size={xSkip-4,bHeight},title="shutter open delay (ms): ",value=jSc_GatePadStart,limits={0,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable shutterPostPadSV,pos={x,y+3},size={xSkip-4,bHeight},title="shutter close delay (ms): ",value=jSc_GatePadEnd,limits={0,Inf,0.1},fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable SpiralArc,pos={x,y+3},size={xSkip-4,bHeight},title="spiral arc (mV): ",value=jSc_SpiralArc,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable SpiralSeparation,pos={x,y+3},size={xSkip-4,bHeight},title="separation (mV): ",value=jSc_SpiralSeparation,limits={1,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable stimWaitSV,pos={x,y+3},size={xSkip-4,bHeight},title="wait after run (s): ",value=jSc_stimWait,limits={3,Inf,1},fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button EditSpikeListsButton,pos={x,y},size={xSkip-4,bHeight},proc=jSc_EditSpikeListsProc,title="↓ Edit spike lists ↓",fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable deltaT1_SV,pos={x,y+3},size={xSkip-4,bHeight},title="dT start value (ms): ",value=jSc_deltaT1,limits={-Inf,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable deltaT2_SV,pos={x,y+3},size={xSkip-4,bHeight},title="dT end value (ms): ",value=jSc_deltaT2,limits={-Inf,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable noSpikeListSV,pos={x,y+3},size={xSkip-4,bHeight},title="no spikes: ",value=jSc_noSpikeList,fsize=fontSize,font="Arial"
	x += xSkip
	xSkip = floor((Width-xMargin*2)/6)
	Button noSpike1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="0000...",fsize=fontSize,font="Arial"
	x += xSkip
	Button noSpike2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="Invert",fsize=fontSize,font="Arial"
	x += xSkip
	Button noSpike3Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="0101...",fsize=fontSize,font="Arial"
	x += xSkip
	Button noSpike4Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="0001...",fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable spikeOffsetListSV,pos={x,y+3},size={xSkip-4,bHeight},title="offset spikes: ",value=jSc_addOffsetList,fsize=fontSize,font="Arial"
	x += xSkip
	xSkip = floor((Width-xMargin*2)/6)
	SetVariable spikeOffsetSV,pos={x,y+3},size={xSkip-4,bHeight},title=" ",value=jSc_spikeOffset,limits={-Inf,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	Button addOffset1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_addOffsetProc,title="0000...",fsize=fontSize,font="Arial"
	x += xSkip
	Button addOffset2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_addOffsetProc,title="0101...",fsize=fontSize,font="Arial"
	x += xSkip
	Button addOffset3Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_addOffsetProc,title="0123...",fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable lastSpikeStaggerSV,pos={x,y+3},size={xSkip-4,bHeight},title="Stagger last spikes (ms): ",value=jSc_staggerLastSpikeAcrossChannels,limits={0,Inf,100},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable padAfterLastSpikeSV,pos={x,y+3},size={xSkip-4,bHeight},title="Pad after last spikes (ms): ",value=jSc_padAfterLastSpike,limits={0,Inf,100},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable stimRunCounterSV,pos={x,y+3},size={xSkip-4,bHeight},title="run counter: ",value=jSc_stimRunCounter,limits={5,Inf,0},fsize=fontSize,font="Arial",noEdit=1,frame=1
	x += xSkip
	SetVariable maxUncRunsSV,pos={x,y+3},size={xSkip-4,bHeight},title="maximum runs: ",value=jSc_maxStimRuns,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable uncSuffixSV,pos={x,y+3},size={xSkip-4,bHeight},title="suffix: ",value=jSc_stim_Suffix,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/5)
	x = xMargin
	Button MakePathButton,pos={x,y},size={xSkip*2-4,bHeight},proc=jSc_2pZapMakePathProc,title="Convert points to path",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	x += xSkip
	Button ZapRunButton,pos={x,y},size={xSkip*2-4,bHeight},proc=jSc_stimRunProc,title="Run 2p zap pattern",fsize=fontSize,font="Arial",fColor=(0,0,65535)
	x += xSkip
	x += xSkip
	Button closeUncPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=JT_WinCloseProc,title="Close",fsize=fontSize,font="Arial",fColor=(65535,0,0)
	x += xSkip
	y += ySkip

	MoveWindow/W=j2pZapPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the jUncage panel

Function jSc_makeUncPanelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Make_jUncagePanel()
			break
	endswitch

	return 0
End

Function Make_jUncagePanel()

	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 420
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow jUncagePanel
	if (V_flag)
		GetWindow jUncagePanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
	endif

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12

	DoWindow/K jUncagePanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "jScan Uncaging Panel"
	DoWindow/C jUncagePanel
	ModifyPanel/W=jUncagePanel fixedSize=1
	
	//////////////////// Uncaging stuff
	
	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetDrawEnv fstyle= 5,fsize= 14,textyjust= 2
	DrawText x,y+5,"Uncaging parameters"
	x += xSkip
	SetVariable unc_sampFreqSV,pos={x,y+3},size={xSkip-4,bHeight},title="sampling freq (Hz): ",value=jSc_stim_sampFreq,limits={500,Inf,500},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable uncxSizeSV,pos={x,y+3},size={xSkip-4,bHeight},title="grid x size: ",value=jSc_stim_xSize,proc=jSc_stimSizeChangedProc,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable uncySizeSV,pos={x,y+3},size={xSkip-4,bHeight},title="grid y size: ",value=jSc_stim_ySize,proc=jSc_stimSizeChangedProc,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable uncGapSV,pos={x,y+3},size={xSkip-4,bHeight},title="minimum gap: ",value=jSc_unc_gap,limits={0,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable flySV,pos={x,y+3},size={xSkip-4,bHeight},title="fly (ms): ",value=jSc_unc_flyTime,limits={0.1,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable dwellSV,pos={x,y+3},size={xSkip-4,bHeight},title="dwell (ms): ",value=jSc_stim_dwellTime,limits={100,Inf,100},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable shutterSV,pos={x,y+3},size={xSkip-4,bHeight},title="open (ms): ",value=jSc_stim_shutterTime,limits={0.1,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable stimPulsePrePadSV,pos={x,y+3},size={xSkip-4,bHeight},title="prepad (ms): ",value=jSc_stim_PulsePrePad,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable stimnPulsesSV,pos={x,y+3},size={xSkip-4,bHeight},title="# of pulses: ",value=jSc_stim_nPulses,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable uncFreqSV,pos={x,y+3},size={xSkip-4,bHeight},title="frequency (Hz): ",value=jSc_stim_freq,limits={1,Inf,10},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable shutterClosedValSV,pos={x,y+3},size={xSkip-4,bHeight},title="gate closed value (V): ",value=jSc_stim_shutterClosed,limits={-Inf,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable shutterOpenValSV,pos={x,y+3},size={xSkip-4,bHeight},title="gate open value (V): ",value=jSc_stim_shutterOpen,limits={-Inf,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable stimWaitSV,pos={x,y+3},size={xSkip-4,bHeight},title="wait after run (s): ",value=jSc_stimWait,limits={5,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	NVAR	jSc_reRandomize
	CheckBox reRandomizeCheck,pos={x,y+4},title="re-randomize before make",proc=jSc_readStimChBoxProc,value=jSc_reRandomize,fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable deltaT1_SV,pos={x,y+3},size={xSkip-4,bHeight},title="dT start value (ms): ",value=jSc_deltaT1,limits={-Inf,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable deltaT2_SV,pos={x,y+3},size={xSkip-4,bHeight},title="dT end value (ms): ",value=jSc_deltaT2,limits={-Inf,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable noSpikeListSV,pos={x,y+3},size={xSkip-4,bHeight},title="no spikes: ",value=jSc_noSpikeList,fsize=fontSize,font="Arial"
	x += xSkip
	xSkip = floor((Width-xMargin*2)/6)
	Button noSpike1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="0000...",fsize=fontSize,font="Arial"
	x += xSkip
	Button noSpike2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="Invert",fsize=fontSize,font="Arial"
	x += xSkip
	Button noSpike3Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="0101...",fsize=fontSize,font="Arial"
	x += xSkip
	Button noSpike4Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_noSpikeProc,title="0001...",fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable spikeOffsetListSV,pos={x,y+3},size={xSkip-4,bHeight},title="offset spikes: ",value=jSc_addOffsetList,fsize=fontSize,font="Arial"
	x += xSkip
	xSkip = floor((Width-xMargin*2)/6)
	SetVariable spikeOffsetSV,pos={x,y+3},size={xSkip-4,bHeight},title=" ",value=jSc_spikeOffset,limits={-Inf,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	Button addOffset1Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_addOffsetProc,title="0000...",fsize=fontSize,font="Arial"
	x += xSkip
	Button addOffset2Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_addOffsetProc,title="0101...",fsize=fontSize,font="Arial"
	x += xSkip
	Button addOffset3Button,pos={x,y},size={xSkip-4,bHeight},proc=jSc_addOffsetProc,title="0123...",fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable stimRunCounterSV,pos={x,y+3},size={xSkip-4,bHeight},title="run counter: ",value=jSc_stimRunCounter,limits={5,Inf,0},fsize=fontSize,font="Arial",noEdit=1,frame=1
	x += xSkip
	SetVariable maxUncRunsSV,pos={x,y+3},size={xSkip-4,bHeight},title="maximum runs: ",value=jSc_maxStimRuns,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable uncSuffixSV,pos={x,y+3},size={xSkip-4,bHeight},title="suffix: ",value=jSc_stim_Suffix,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/5)
	x = xMargin
	Button uncCreateButton,pos={x,y},size={xSkip*2-4,bHeight},proc=jSc_uncCreateProc,title="Make uncaging pattern",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	x += xSkip
	Button uncRunButton,pos={x,y},size={xSkip*2-4,bHeight},proc=jSc_stimRunProc,title="Run uncaging pattern",fsize=fontSize,font="Arial",fColor=(0,0,65535)
	x += xSkip
	x += xSkip
	Button closeUncPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=JT_WinCloseProc,title="Close",fsize=fontSize,font="Arial",fColor=(65535,0,0)
	x += xSkip
	y += ySkip

	MoveWindow/W=jUncagePanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Tweak the no-spike and offset-spike lists to ensure they match the number of selected points.

Function jSc_makeSpikeListsMatchNpoints()

	NVAR		jSc_nPoints
	SVAR		jSc_noSpikeList
	SVAR		jSc_addOffsetList
	
	// jSc_noSpikeList, too few
	if (ItemsInList(jSc_noSpikeList)<jSc_nPoints)
		print "Found too few points in jSc_noSpikeList — rectified!"
		do
			jSc_noSpikeList += "0;"
		while(ItemsInList(jSc_noSpikeList)<jSc_nPoints)
	endif

	// jSc_noSpikeList, too many
	if (ItemsInList(jSc_noSpikeList)>jSc_nPoints)
		print "Found too many points in jSc_noSpikeList — rectified!"
		do
			jSc_noSpikeList = RemoveListItem(ItemsInList(jSc_noSpikeList)-1,jSc_noSpikeList)
		while(ItemsInList(jSc_noSpikeList)>jSc_nPoints)
	endif

	// jSc_addOffsetList, too few
	if (ItemsInList(jSc_addOffsetList)<jSc_nPoints)
		print "Found too few points in jSc_addOffsetList — rectified!"
		do
			jSc_addOffsetList += "0;"
		while(ItemsInList(jSc_addOffsetList)<jSc_nPoints)
	endif

	// jSc_addOffsetList, too many
	if (ItemsInList(jSc_addOffsetList)>jSc_nPoints)
		print "Found too many points in jSc_addOffsetList — rectified!"
		do
			jSc_addOffsetList = RemoveListItem(ItemsInList(jSc_addOffsetList)-1,jSc_addOffsetList)
		while(ItemsInList(jSc_addOffsetList)>jSc_nPoints)
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Map no-spikes button to right function

Function jSc_EditSpikeListsProc(ba) : ButtonControl
	STRUCT 		WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			jSc_doEditSpikeLists()
			break
		case -1: // control being killed
			break
	endswitch

	return 0

End


Function jSc_doEditSpikeLists()

	NVAR		jSc_stim_xSize	
	NVAR		jSc_stim_ySize	
	SVAR		jSc_noSpikeList
	SVAR		jSc_addOffsetList
	
	if (Exists("jSc_nPoints"))
		NVAR jSc_nPoints
	else
		Variable/G	jSc_nPoints = jSc_stim_xSize*jSc_stim_ySize
	endif

	if ( (itemsinlist(jSc_noSpikeList)!=jSc_nPoints) %| (itemsinlist(jSc_addOffsetList)!=jSc_nPoints) )
		jSc_makeSpikeListsMatchNpoints()
	endif
	
	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 200
	Variable		Ypos = 64
	
	// If panel already exists, keep it in the same place, please
	DoWindow jSpikeEditPanel
	Variable panelExists = V_flag
	if (panelExists)
		GetWindow jSpikeEditPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
	endif

	Variable		xMargin = 4
	Variable		bHeight = 20
	Variable		yMargin = 4
	Variable		x = xMargin
	Variable		y = yMargin
	Variable		bSp = 2
	Variable		lSp = 4
	Variable		fontSize=11

	if (Exists("jSC_EditPanel_maxCols")==0)
		Variable/G	jSC_EditPanel_maxCols = 8					// Number of columns
	else
		NVAR			jSC_EditPanel_maxCols
	endif
	Variable		colWidth = 120
	Variable		rowHeight = bHeight+lSp
	Variable		Width = xMargin + jSC_EditPanel_maxCols*colWidth + xMargin
	Variable		Height = yMargin+(Ceil(jSc_nPoints/jSC_EditPanel_maxCols)+1)*rowHeight+yMargin
	
	Variable		checkSize = 36
	Variable		buttonSize = 15
	Variable		setVarSize = 20

	DoWindow/K jSpikeEditPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width,yPos*ScSc+Height) as "Edit Spike List"
	DoWindow/C jSpikeEditPanel
	ModifyPanel/W=jSpikeEditPanel fixedSize=1
	
	if (!panelExists)
		doWindow j2pZapPanel
		if (V_flag)
			AutoPositionWindow/R=j2pZapPanel jSpikeEditPanel
		endif
	endif
	
	Make/O/N=(jSc_nPoints) offsetSVw

	Variable	i,j,xx
	Variable xSp = 120
	Variable	xGap = 4
	xx = x
	SetVariable nColumnsSetVar,pos={xx,y+2},size={xSp,bHeight},title="# columns",proc=maxColsProc,value=jSC_EditPanel_maxCols,limits={4,Inf,1},fSize=(fontSize),font="Arial"
	xx += xSp+xGap
	xSp = 80
	Button closeButton,pos={xx,y-1},size={xSp,bHeight},proc=JT_WinCloseProc,title="Done editing!",fSize=(fontSize),font="Arial",fColor=(0,65535,0)
	xx += xSp+xGap
	xSp = 110
	Button convertButton1,pos={xx,y-1},size={xSp,bHeight},proc=jSc_EPSPsToSpikeListProc,title="Ch1 EPSPs > APs",fSize=(fontSize),font="Arial"
	xx += xSp+xGap
	xSp = 34
	Button convertButton2,pos={xx,y-1},size={xSp,bHeight},proc=jSc_EPSPsToSpikeListProc,title="Ch2",fSize=(fontSize),font="Arial"
	xx += xSp+xGap
	Button convertButton3,pos={xx,y-1},size={xSp,bHeight},proc=jSc_EPSPsToSpikeListProc,title="Ch3",fSize=(fontSize),font="Arial"
	xx += xSp+xGap
	Button convertButton4,pos={xx,y-1},size={xSp,bHeight},proc=jSc_EPSPsToSpikeListProc,title="Ch4",fSize=(fontSize),font="Arial"
	xx += xSp+xGap
	y += rowHeight

	Variable checkVal
	i = 0
	j = 1
	do
		checkVal = str2num(StringFromList(i,jSc_noSpikeList))
		offsetSVw[i] = str2num(StringFromList(i,jSc_addOffsetList))
		xx = x + round((colWidth-(checkSize+bSp+buttonSize+bSp+setVarSize+bSp+buttonSize+bSp))/2)
		CheckBox $("noSp_"+num2str(i)),pos={xx,y+2},size={checkSize,bHeight},proc=jSc_EditSpikeListCheckboxProc,value=checkVal,title=JT_num2digstr(3,i),side=1,fSize=(fontSize),font="Arial"
		xx += checkSize+bSp
		Button $("dButton_"+num2str(i)),pos={xx,y-1},size={buttonSize,bHeight},proc=jSc_EditSpikeListButtonProc,title="↓",fSize=(fontSize),font="Arial"
		xx += buttonSize+bSp
		SetVariable $("offsetSV_"+num2str(i)),pos={xx,y+2},size={setVarSize,bHeight},title=" ",value=offsetSVw[i],limits={-Inf,Inf,0},frame=0,noedit=1,fSize=(fontSize),font="Arial"
		xx += setVarSize+bSp
		Button $("uButton_"+num2str(i)),pos={xx,y-1},size={buttonSize,bHeight},proc=jSc_EditSpikeListButtonProc,title="↑",fSize=(fontSize),font="Arial"
		xx += buttonSize+bSp
		x += colWidth
		j += 1
		if (j>jSC_EditPanel_maxCols)
			j = 1
			x = xMargin
			y += rowHeight
		endif
		i += 1
	while(i<jSc_nPoints)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Up/Down spike-edit buttons

Function jSc_EPSPsToSpikeListProc(ba) : ButtonControl
	STRUCT 		WMButtonAction &ba
	
	String		ctrlName = ba.ctrlName


	switch( ba.eventCode )
		case 2: // mouse up
			SVAR			jSc_noSpikeList
			Variable		channelNumber = str2num(ctrlName[13])
			if (Exists("JT_LD_responseWave"+num2str(channelNumber))==0)
				Print "You need to load recently acquired data first to find connections!"
				Abort "You need to load recently acquired data first to find connections!"
			endif
			WAVE/Z		JT_LD_responseWave = $("JT_LD_responseWave"+num2str(channelNumber))			// Now relying on JT's LoadData panel, since MP's has been deprecated
			Variable	n = numpnts(JT_LD_responseWave)
			Variable	i
			print "Setting those inputs with EPSPs to have spikes, others not, for channel "+num2str(channelNumber)+"."
			jSc_noSpikeList = ""
			i = 0
			do
				if (JT_LD_responseWave[i])
					jSc_noSpikeList += "0;"
				else
					jSc_noSpikeList += "1;"
				endif
				i += 1
			while(i<n)
			jSc_doEditSpikeLists()			// Update Edit Spike List panel.
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Number of columns was changed

Function maxColsProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			jSc_doEditSpikeLists()
			break
		case -1: // control being killed
			break
	endswitch

	return 0

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Convert panel settings to lists

Function jSc_parseEditSpikeListPanel()

	SVAR		jSc_noSpikeList
	SVAR		jSc_addOffsetList
	NVAR		jSc_nPoints
	WAVE		offsetSVw
	
	jSc_noSpikeList = ""
	jSc_addOffsetList = ""

	Variable	i
	i = 0
	do
		controlInfo/W=jSpikeEditPanel $("noSp_"+num2str(i))
		jSc_noSpikeList += num2str(V_Value)+";"
		jSc_addOffsetList += num2str(offsetSVw[i])+";"
		i += 1
	while(i<jSc_nPoints)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Spike-edit checkboxes

Function jSc_EditSpikeListCheckboxProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable		checked
	
	jSc_parseEditSpikeListPanel()
		
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Up/Down spike-edit buttons

Function jSc_EditSpikeListButtonProc(ba) : ButtonControl
	STRUCT 		WMButtonAction &ba
	
	String		ctrlName = ba.ctrlName
	
	WAVE			offsetSVw
	
	Variable		index = str2num(ctrlName[8,10])

	switch( ba.eventCode )
		case 2: // mouse up
			if (StringMatch(ctrlName[0],"d"))
				offsetSVw[index] -= 1
			else
				offsetSVw[index] += 1
			endif
			jSc_parseEditSpikeListPanel()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Map no-spikes button to right function

Function jSc_noSpikeProc(ba) : ButtonControl
	STRUCT 		WMButtonAction &ba
	
	Variable		buttonType = 0
	String		ctrlName

	switch( ba.eventCode )
		case 2: // mouse up
			ctrlName = ba.ctrlName
			buttonType = str2num(ctrlName[7])
			jSc_makeNoSpikeList(buttonType)
			// Update the spike edit window, if open
			DoWindow jSpikeEditPanel
			if (V_flag)
				jSc_doEditSpikeLists()
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the list definining which postsynaptic current injections should be ommitted
//// 1 - All zeros, keep all spikes
//// 2 - Invert the pattern, ones become zeros, zeros become ones
//// 3 - Alternate zeros and ones, so keep every other spike
//// 4 - Every fourth entry is a one, so drop every 4th spike

Function jSc_makeNoSpikeList(patternType)
	Variable	patternType

	NVAR		jSc_stim_xSize	
	NVAR		jSc_stim_ySize	
	SVAR		jSc_noSpikeList
	
	if (Exists("jSc_nPoints"))
		NVAR jSc_nPoints
	else
		Variable/G	jSc_nPoints = jSc_stim_xSize*jSc_stim_ySize
	endif
	
	Variable	i,j
	Variable	currEntry
	
	switch(patternType)
		case 1:
			jSc_noSpikeList = ""
			i = 0
			do
				jSc_noSpikeList += "0;"
				i += 1
			while (i<jSc_nPoints)
			break
		case 2:
			if (itemsinlist(jSc_noSpikeList)!=jSc_nPoints)
				jSc_makeSpikeListsMatchNpoints()
			endif
			i = 0
			do
				currEntry = str2num(stringfromlist(i,jSc_noSpikeList))
				if (currEntry)
					jSc_noSpikeList = RemoveListItem(i,jSc_noSpikeList)
					jSc_noSpikeList = AddListItem("0",jSc_noSpikeList,";",i)
				else
					jSc_noSpikeList = RemoveListItem(i,jSc_noSpikeList)
					jSc_noSpikeList = AddListItem("1",jSc_noSpikeList,";",i)
				endif
				i += 1
			while (i<jSc_nPoints)
			break
		case 3:
			jSc_noSpikeList = ""
			i = 0
			do
				if (mod(i+1,2))
					jSc_noSpikeList += "0;"
				else
					jSc_noSpikeList += "1;"
				endif
				i += 1
			while (i<jSc_nPoints)
			break
		case 4:
			jSc_noSpikeList = ""
			i = 0
			do
				if (mod(i+1,4))
					jSc_noSpikeList += "0;"
				else
					jSc_noSpikeList += "1;"
				endif
				i += 1
			while (i<jSc_nPoints)
			break
		default:
			print "Strange error in jSc_makeNoSpikeList"
			abort "Strange error in jSc_makeNoSpikeList"
	endswitch
	Variable	allOnes = 1
	i = 0
	do
		if (str2num(stringfromlist(i,jSc_noSpikeList)) == 0)
			allOnes = 0
			i = inf
		endif
		i += 1
	while(i<jSc_nPoints)
	if (allOnes)
		print "NB! No spikes at all will result in a bug, so one spike was added in the last position."
		jSc_noSpikeList = RemoveListItem(itemsInList(jSc_noSpikeList)-1,jSc_noSpikeList)
		jSc_noSpikeList = AddListItem("0",jSc_noSpikeList,";",itemsInList(jSc_noSpikeList))
	endif
	print "Current no-spike list:"
	print jSc_noSpikeList

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Map spike-offset button to right function

Function jSc_addOffsetProc(ba) : ButtonControl
	STRUCT 		WMButtonAction &ba
	
	Variable		buttonType = 0
	String		ctrlName

	switch( ba.eventCode )
		case 2: // mouse up
			ctrlName = ba.ctrlName
			buttonType = str2num(ctrlName[9])
			jSc_makeAddOffsetList(buttonType)
			// Update the spike edit window, if open
			DoWindow jSpikeEditPanel
			if (V_flag)
				jSc_doEditSpikeLists()
			endif
			break
		case -1:
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the list definining which postsynaptic current injections should be ommitted
//// 1 - All zeros, no offset
//// 2 - Alternate zeros and ones, so add offset for every other spike
//// 3 - 01230123..., so no offset on first, offset on second, double offset on third, triple offset on fourth, etc.

Function jSc_makeAddOffsetList(patternType)
	Variable	patternType

	NVAR		jSc_stim_xSize	
	NVAR		jSc_stim_ySize	
	SVAR		jSc_addOffsetList
	
	if (Exists("jSc_nPoints"))
		NVAR jSc_nPoints
	else
		Variable/G	jSc_nPoints = jSc_stim_xSize*jSc_stim_ySize
	endif
	
	variable	i,j
	Variable	currEntry
	
	switch(patternType)
		case 1:
			jSc_addOffsetList = ""
			i = 0
			do
				jSc_addOffsetList += "0;"
				i += 1
			while (i<jSc_nPoints)
			break
		case 2:
			jSc_addOffsetList = ""
			i = 0
			do
				if (mod(i+1,2))
					jSc_addOffsetList += "0;"
				else
					jSc_addOffsetList += "1;"
				endif
				i += 1
			while (i<jSc_nPoints)
			break
		case 3:
			jSc_addOffsetList = ""
			i = 0
			do
				jSc_addOffsetList += num2str(mod(i,4))+";"
				i += 1
			while (i<jSc_nPoints)
			break
		default:
			print "Strange error in jSc_makeAddOffsetList"
			abort "Strange error in jSc_makeAddOffsetList"
	endswitch
	print "Current spike-offset list:"
	print jSc_addOffsetList
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read and store rerandomize checkbox value from uncaging panel

Function jSc_stimSizeChangedProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR		jSc_stim_mustRerandom
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			jSc_stim_mustRerandom = 1
			print "Grid size was changed --> re-randomization is forced before next Make."
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read and store rerandomize checkbox value from uncaging panel

Function jSc_readStimChBoxProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	NVAR	jSc_reRandomize
	jSc_reRandomize = checked
	if (jSc_reRandomize)
		print "Uncaging pattern will be re-ranomized in between uncaging runs."
	else
		print "Uncaging pattern will not be re-ranomized in between uncaging runs."
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read and store burst-frame checkbox value from main panel

Function jSc_readBurstChBoxProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	NVAR		jSc_nBurstFrames
	NVAR		jSc_burstFrames
	jSc_burstFrames = checked
	if (jSc_burstFrames)
		print "Burst frames ON. Will now transfer nBurstFrames = "+num2str(jSc_nBurstFrames)+" frames without processing them until the end."
	else
		print "Burst frames OFF."
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read and store average checkbox value from main panel

Function jSc_readAveChBoxProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	NVAR	jSc_averageFrames
	jSc_averageFrames = checked
	if (jSc_averageFrames)
		print "Frames will be averaged."
	else
		print "Frames will not be averaged."
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read and store linescan checkbox value from main panel

Function jSc_readLSChBoxProc(ctrlName,checked) : CheckBoxControl
	String		ctrlName
	Variable	checked
	
	NVAR	jSc_LSflag
	jSc_LSflag = checked
	if (jSc_LSflag)
		print "Switching to linescan operation."
	else
		print "Switching to framescan operation."
	endif

	jSc_remakeScanIOdata()
	jSc_setImageAspectRatio()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set aspect ratio of images 
//// depending on whether framescan or linscan is running

Function jSc_setImageAspectRatio()

	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on

	NVAR		jSc_LSflag
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf

	Variable	AspectRatio = abs(jSc_yAmp/jSc_xAmp)

	if (jSc_LSflag)
		AspectRatio = abs(jSc_lnpf/jSc_pxpl)
	endif

	if (jSc_Ch1on)
		ModifyGraph/Z/W=jSc_ImageViewer1 height={Aspect,AspectRatio}
	endif
	if (jSc_Ch2on)
		ModifyGraph/Z/W=jSc_ImageViewer2 height={Aspect,AspectRatio}
	endif
	if (jSc_Ch3on)
		ModifyGraph/Z/W=jSc_ImageViewer3 height={Aspect,AspectRatio}
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read and store channel checkbox values from main panel

Function jSc_readChBoxProc(ctrlName,checked) : CheckBoxControl
	String	ctrlName
	Variable	checked
	
	NVAR	jSc_Ch1on
	NVAR	jSc_Ch2on
	NVAR	jSc_Ch3on
	
	Variable	channel = str2num(ctrlName[5,5])
	
	if (checked)
		print "Channel #"+num2str(channel)+" was checked."
	else
		print "Channel #"+num2str(channel)+" was unchecked."
	endif
	
	NVAR	storeVar = $("jSc_Ch"+num2str(channel)+"on")
	storeVar = checked

	if ((jSc_Ch1on==0) %& (jSc_Ch2on==0) %& (jSc_Ch3on==0))
		Beep
		print "\tAll three checkboxes are now unchecked -- this is not allowed, so I'm putting that checkmark right back!"
		storeVar = 1
		CheckBox $("UseCh"+num2str(channel)+"Check"),value=storeVar,win=jScanPanel
	endif
	
	jSc_drawImages()
	DoWindow/F jScanPanel

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Reinit jScPlots

Function jSc_ReInitProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- Reinitiating jScan ---"
			init_jScan()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Redraw images

Function jSc_RedrawImagesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			jSc_drawImages()
			DoWindow/F jScanPanel
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Redraw panel

Function jSc_RedrawPanelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Make_jScanPanel()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Apply Quick Setting

Function jSc_QSProc(ctrlName) : ButtonControl
	String ctrlName

	Variable QSno = str2num(ctrlName[2,2])		// Limitation: no more than 10 Quick Settings are possible
	jSc_applyQS(QSno)
	
End

Function jSc_applyQS(QSno)
	Variable	QSno
	
	SVAR	identifier = $("jSc_QS"+num2str(QSno)+"_name")
	SVAR	jSc_QS_pList
	
	print		"Applying Quick Setting #"+num2str(QSno)+": \""+identifier+"\""
	
	Variable	n = ItemsInList(jSc_QS_pList)		// Number of parameters in each Quick Setting
	Variable	i
	i = 0
	do
		NVAR	sourceVar = $("jSc_QS"+num2str(QSno)+"_"+StringFromList(i,jSc_QS_pList))
		NVAR	destVar = $("jSc_"+StringFromList(i,jSc_QS_pList))
		destVar = sourceVar
		i += 1
	while(i<n)
	
	// Update checkboxes in panel
	NVAR 	jSc_Ch1on
	NVAR 	jSc_Ch2on
	NVAR 	jSc_Ch3on
	CheckBox UseCh1Check,value=jSc_Ch1on,win=jScanPanel
	CheckBox UseCh2Check,value=jSc_Ch2on,win=jScanPanel
	CheckBox UseCh3Check,value=jSc_Ch3on,win=jScanPanel
	NVAR 	jSc_LSflag
	NVAR	jSc_burstFrames
	NVAR	jSc_averageFrames
	CheckBox LSCheck,value=jSc_LSflag,win=jScanPanel
	CheckBox aveFramesCheck,value=jSc_averageFrames,win=jScanPanel
	CheckBox burstFramesCheck,value=jSc_burstFrames,win=jScanPanel
	
	// Apply settings
	jSc_remakeScanIOdata()
	jSc_calcTotMspl()
	jSc_makeFrames()
	jSc_drawImages()
	DoWindow/F jScanPanel

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Kill Quick Setting variables -- USE WITH CAUTION

Function jSc_killAllQS()

	print "Killing all QS variables"

	SVAR	jSc_QS_pList
	NVAR	jSc_nQS
	
	Variable	n = ItemsInList(jSc_QS_pList)		// Number of parameters in each Quick Setting
	Variable	i,j
	j = 0
	do
		i = 0
		do
			KillVariables/Z $("jSc_QS"+num2str(j+1)+"_"+StringFromList(i,jSc_QS_pList))
			print "Killing: "+"jSc_QS"+num2str(j+1)+"_"+StringFromList(i,jSc_QS_pList)
			i += 1
		while(i<n)
		j += 1
	while(j<jSc_nQS)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Dump Quick Setting for saving

Function jSc_dumpQS()
	printf "--- Dumping QS ---"

	SVAR	jSc_QS_pList
	NVAR	jSc_nQS
	
	Variable	n = ItemsInList(jSc_QS_pList)		// Number of parameters in each Quick Setting
	Variable	i,j
	j = 0
	do
		SVAR	str = $("jSc_QS"+num2str(j+1)+"_name")
		printf "\rjSc_QS"+num2str(j+1)+"_name:"+str+";"
		i = 0
		do
			NVAR	value = $("jSc_QS"+num2str(j+1)+"_"+StringFromList(i,jSc_QS_pList))
			printf "\rjSc_QS"+num2str(j+1)+"_"+StringFromList(i,jSc_QS_pList)+":"+num2str(value)+";"
			i += 1
		while(i<n)
		j += 1
	while(j<jSc_nQS)
	printf "\r"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Open or close the galvo shutter

Function jSc_galvoShutterProc(ctrlName) : ButtonControl
	String ctrlName

	Variable	shutterAction = str2num(ctrlName[7+5,7+5])
	
	NVAR		jSc_stim_shutterOpen
	NVAR		jSc_stim_shutterClosed
	
	switch(shutterAction)
		case 1:
			print "--- Open shutter ---"
			jSc_parkGalvoShutter(jSc_stim_shutterOpen)
			break
		case 2:
			print "--- Close shutter ---"
			jSc_parkGalvoShutter(jSc_stim_shutterClosed)
			break
	endswitch

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Open or close the mechanical shutter

Function jSc_shutterProc(ctrlName) : ButtonControl
	String ctrlName

	Variable shutterAction = str2num(ctrlName[7,7])
	
	switch(shutterAction)
		case 1:
			print "--- Open shutter ---"
			jSc_openShutter()
			break
		case 2:
			print "--- Close shutter ---"
			jSc_closeShutter()
			break
	endswitch

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Open shutter

Function jSc_openShutter()

	SVAR	jSc_shutterDevStr
	NVAR	jSc_shutterPin
	NVAR	jSc_VerboseMode

#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: jSc_openShutter simulated"
	endif
#else
	DAQmx_DIO_Config/DEV=jSc_shutterDevStr/DIR=1 "/"+jSc_shutterDevStr+"/port0/line"+num2str(jSc_shutterPin)
	fDAQmx_DIO_Write(jSc_shutterDevStr, V_DAQmx_DIO_TaskNumber,2^(jSc_shutterPin))
	fDAQmx_DIO_Finished(jSc_shutterDevStr, V_DAQmx_DIO_TaskNumber)
#endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Close shutter

Function jSc_closeShutter()

	SVAR	jSc_shutterDevStr
	NVAR	jSc_shutterPin
	NVAR	jSc_VerboseMode

#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: jSc_closeShutter simulated"
	endif
#else
	DAQmx_DIO_Config/DEV=jSc_shutterDevStr/DIR=1 "/"+jSc_shutterDevStr+"/port0/line"+num2str(jSc_shutterPin)
	fDAQmx_DIO_Write(jSc_shutterDevStr, V_DAQmx_DIO_TaskNumber,0)
	fDAQmx_DIO_Finished(jSc_shutterDevStr, V_DAQmx_DIO_TaskNumber)
#endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Reset board

Function jSc_resetBoardProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			jSc_initBoard()
			break
	endswitch

	return 0
End

Function jSc_initBoard()

	SVAR		jSc_inDevStr
	SVAR		jSc_outDevStr
	
#ifdef DemoMode
	print "\t\tDemoMode: Resetting board and connecting terminals."
#else
	Variable errCode
	Print "Resetting "+jSc_inDevStr+" at time "+Time()+"."	
	fDAQmx_ResetDevice(jSc_inDevStr)
	errCode =  fDAQmx_ConnectTerminals("/"+jSc_inDevStr+"/ao/starttrigger","/"+jSc_inDevStr+"/PFI6",0)
	if (errCode)
		print "{jSc_initBoard} "+jSc_inDevStr+" Strange error, cannot rewire AO starttrigger to PFI6."
		Abort "{jSc_initBoard} "+jSc_inDevStr+" Strange error, cannot rewire AO starttrigger to PFI6."
	endif
	errCode =  fDAQmx_ConnectTerminals("/"+jSc_inDevStr+"/ai/starttrigger","/"+jSc_inDevStr+"/PFI0",0)
	if (errCode)
		print "{jSc_initBoard} "+jSc_inDevStr+" Strange error, cannot rewire AI starttrigger to PFI0."
		Abort "{jSc_initBoard} "+jSc_inDevStr+" Strange error, cannot rewire AI starttrigger to PFI0."
	endif
	if (!(StringMatch(jSc_inDevStr,jSc_outDevStr)))
		Print "Resetting "+jSc_outDevStr+" at time "+Time()+"."	
		fDAQmx_ResetDevice(jSc_outDevStr)
		errCode = fDAQmx_ConnectTerminals("/"+jSc_outDevStr+"/ao/StartTrigger", "/"+jSc_outDevStr+"/PFI0", 0)
		if (errCode)
			print "WARNING! Could not hook up output trigger properly!"
			print "{jSc_initBoard} "+jSc_outDevStr+" Strange error, cannot rewire AO starttrigger to PFI0."
			Abort "{jSc_initBoard} "+jSc_outDevStr+" Strange error, cannot rewire AO starttrigger to PFI0."
		endif
	endif
#endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Print most recent error in the error buffer

Function jSc_printError()

#ifdef DemoMode
	print "\t\tDemoMode: simulating jSc_printError"
#else
	String errStr = fDAQmx_ErrorString()
	if (StrLen(errStr)>1)
		Print "Most recent error in error buffer is:"
		print errStr
	else
		Print "Error buffer is empty -- no error could be fetched."
	endif
#endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set stack start or end position

Function jSc_stkPosProc(ctrlName) : ButtonControl
	String		ctrlName
	Variable	choice = str2num(ctrlName[8,8])
	
	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ
	
	NVAR		jSc_stgX_store
	NVAR		jSc_stgY_store
	NVAR		jSc_stgZ_store
	
	NVAR		jSc_ETL_store
	
	NVAR		jSc_stkStart
	NVAR		jSc_stkEnd
	NVAR		jSc_nSlices
	NVAR		jSc_stkSliceSpacing
	
	NVAR		jSc_ETLstack
	NVAR		jSc_ETLcommand
	NVAR		jSc_ETLmicron
	
	jSc_COM_getPos()

	switch(choice)
		case 1:
			if (jSc_ETLstack)
				jSc_stkStart = jSc_ETLmicron
				jSc_ETL_store = jSc_ETLmicron
				print "Set stack start to "+num2str(jSc_stkStart)+" µm (ETL command voltage "+num2str(jSc_ETLcommand)+" V)"
			else
				jSc_stkStart = Round(jSc_stgZ)
				print "Set stack start to "+num2str(jSc_stkStart)+" µm"
			endif
			jSc_stgX_store = jSc_stgX
			jSc_stgY_store = jSc_stgY
			jSc_stgZ_store = Round(jSc_stgZ)
			break
		case 2:
			if (jSc_ETLstack)
				jSc_stkEnd = jSc_ETLmicron
				print "Set stack end to "+num2str(jSc_stkStart)+" µm (ETL command voltage "+num2str(jSc_ETLcommand)+" V)"
			else
				jSc_stkEnd = Round(jSc_stgZ)
				print "Set stack end to "+num2str(jSc_stkEnd)
			endif
			break
	endswitch
	
	jSc_nSlices = Round(abs(jSc_stkEnd-jSc_stkStart)/jSc_stkSliceSpacing)+1

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Zoom in and out

Function jSc_zoomProc(ctrlName) : ButtonControl
	String		ctrlName
	Variable	choice = str2num(ctrlName[4,4])
	switch(choice)
		case 1:
			jSc_ZoomIn()
			break
		case 2:
			jSc_ZoomOut()
			break
	endswitch
	
End

Function jSc_ZoomIn()

	NVAR		jSc_ZoomFactor
	
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		jSc_ZoomFactor *= 10
	else
		jSc_ZoomFactor *= 2
	endif

	jSc_remakeScanIOdata()

End

Function jSc_ZoomOut()

	NVAR		jSc_ZoomFactor
	
	Variable 	Keys = GetKeyState(0)
	if (Keys & 2^2)
		jSc_ZoomFactor /= 10
	else
		jSc_ZoomFactor /= 2
	endif
	
	if (jSc_ZoomFactor<1)
		jSc_ZoomFactor = 1
	endif

	jSc_remakeScanIOdata()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Remake scan output and input data

Function jSc_remakeScanIOproc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable		varNum
	String		varStr
	String		varName

	NVAR	jSc_scanAngle
	
	// It probably doesn't matter but I like to keep angles within [-180,180] degrees
	if (jSc_scanAngle>180)
		jSc_scanAngle -= 360
	endif
	if (jSc_scanAngle<-180)
		jSc_scanAngle += 360
	endif

	 jSc_remakeScanIOdata()

End

Function jSc_remakeScanIOdata()

	jSc_makeAORasterData()
	jSc_makeAIRasterData()			// NOTE! jSc_makeAIRasterData has to execute right after jSc_makeAORasterData!
	WAVE	jSc_xRaster
	WAVE	jSc_yRaster
	NVAR	jSc_scanAngle
	jSc_Rotate(jSc_scanAngle,jSc_xRaster,jSc_yRaster)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Scan button

Function jSc_scanProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR		jSc_LoopFlag
	NVAR		jSc_stimFlag

	switch( ba.eventCode )
		case 2: // mouse up
			if (jSc_LoopFlag)
				print "Cannot scan while a loop is running!"
				print "To override in case of error state, execute this first:\rjSc_LoopFlag=0"
				break
			endif
			if (jSc_stimFlag)
				print "Cannot scan while stimulation is running!"
				print "To override in case of error state, execute this first:\rjSc_stimFlag=0"
				break
			endif
			jSc_initScan()
			break
	endswitch

	return 0
End

Function jSc_initScan()

	SVAR		jSc_inDevStr
	NVAR		jSc_ScanFlag
	NVAR		jSc_frameCounter
	NVAR		jSc_BurstFrames

	if (jSc_ScanFlag)					// Stopping a scan
		Print "Interrupting scanning at ",time()
		jSc_ScanFlag = 0				// Don't stop right away -- stop once the frame is done
	else									// Starting a scan
		if (jSc_BurstFrames)
			doAlert/T="Really?" 1,"Burst mode is on. Do you really want burst mode on when starting a scan?"
			if (V_flag==2)
				print "Turning off burst mode during scan."
				print "*** Remember to turn burst mode on again if you need it during the next acquisition. ***"
				jSc_BurstFrames = 0
				CheckBox burstFramesCheck,win=jScanPanel,value=jSc_burstFrames
			else
				print "Running scan in burst mode."
			endif
		endif
		Print "Starting scanning at ",time()
		jSc_ScanFlag = 1
		jSc_frameCounter = 0
		Button ScanButton,title="Stop",fColor=(65535,0,0),win=jScanPanel
		jSc_remakeScanIOdata()
		jSc_openShutter()
		jSc_setupAO()
		jSc_setupAI()
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Grab button

Function jSc_grabProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR		jSc_LoopFlag
	NVAR		jSc_stimFlag

	switch( ba.eventCode )
		case 2: // mouse up
			if (jSc_LoopFlag)
				print "Cannot scan while a loop is running!"
				print "To override in case of error state, execute this first:\rjSc_LoopFlag=0"
				break
			endif
			if (jSc_stimFlag)
				print "Cannot scan while stimulation is running!"
				print "To override in case of error state, execute this first:\rjSc_stimFlag=0"
				break
			endif
			jSc_doGrab()
			break
	endswitch

	return 0
End

Function jSc_doGrab()

	NVAR		jSc_LoopFlag						// When the loop is running, you cannot click Grab button (see above), but Loop still Grabs, so jSc_LoopFlag can be 1!
	NVAR		jSc_ScanFlag
	NVAR		jSc_GrabFlag
	NVAR		jSc_frameCounter

	PathInfo jScPath
	if (V_flag)
		if (jSc_ScanFlag)						// Stopping a grab
			Print "Stopping grab at ",time()
			if (jSc_GrabFlag)					// jSc_recoverAfterScan() sets jSc_GrabFlag to zero, hence this...
				jSc_recoverAfterScan()			// Do not wait until frame is done -- stop right away, mid-scan!
				jSc_saveTIFF(0)					// Save partially acquired image
			else
				jSc_recoverAfterScan()			// Do not wait until frame is done -- stop right away, mid-scan!
			endif
		else										// Starting a grab
			Print "Starting grab at ",time()
			jSc_ScanFlag = 1
			jSc_GrabFlag = 1
			jSc_frameCounter = 0
			if (!jSc_LoopFlag)
				Button GrabButton,title="Stop",fColor=(65535,0,0),win=jScanPanel	// Don't modify Grab button if a loop is running, because the loop takes care of that
			endif
			jSc_initGrabStorage()
			jSc_remakeScanIOdata()
			jSc_openShutter()
			jSc_setupAO()
			jSc_setupAI()
		endif
	else
		Beep
		print "You have to choose a save path first!"
		Abort "You have to choose a save path first!"
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Recover after waveform generation
//// This can be called after stack, after grab, and after scan
//// Loop flag is not affected, though
//// (Note to self: Might be more reliable to split this into recoverAfterScan and recoverAfterStack)

Function jSc_recoverAfterScan()

	NVAR		jSc_GrabStackFlag
	NVAR		jSc_ScanFlag
	NVAR		jSc_GrabFlag
	NVAR		jSc_max_xAmp
	NVAR		jSc_max_yAmp
	
	NVAR		jSc_LoopFlag
//	NVAR		jSc_loopCounter
//	NVAR		jSc_nLoops
	
	NVAR		jSc_ETLexists
	
	SVAR		jSc_inDevStr

	jSc_closeShutter()
	jSc_ScanFlag = 0
	jSc_GrabFlag = 0
	jSc_GrabStackFlag = 0
	if (!jSc_LoopFlag)								// This should not execute during loops, because that reverts buttons when they should not be reverted; jSc_endLoopRun will take care of it instead
		Button ScanButton,title="Scan",fColor=(0,65535,0),win=jScanPanel
		Button GrabButton,title="Grab",fColor=(0,0,65535),win=jScanPanel
		Button/Z grabStackButton,title="Acquire stack",fColor=(0,0,65535),win=jStackPanel
	endif
	if (jSc_ETLexists)								// Enable ETL stack selection after stack acquisition is done
		doWindow jStackPanel
		if (V_flag)
			CheckBox/Z ETLstackCheck,disable=0,win=jStackPanel
		endif
	endif
	jSc_stopWaveformAndScan()
	jSc_parkLaser(jSc_max_xAmp,jSc_max_yAmp)		// Park laser beam in some godforsaken corner to prevent burning the prep should shutter be left open by mistake

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set up analog input for grabbing a stack

Function jSc_setupAIstack()

	SVAR		jSc_inDevStr

	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	NVAR		jSc_vRange1
	NVAR		jSc_vRange2
	NVAR		jSc_vRange3
	
	NVAR		jSc_pixelBin
	
	String		wStr = ""

	if (jSc_Ch1on)
		wStr += "jSc_Ch1raw,0,-"+num2str(0)+","+num2str(jSc_vRange1)+";"
	endif
	if (jSc_Ch2on)
		wStr += "jSc_Ch2raw,1,-"+num2str(0)+","+num2str(jSc_vRange2)+";"
	endif
	if (jSc_Ch3on)
		wStr += "jSc_Ch3raw,2,-"+num2str(0)+","+num2str(jSc_vRange3)+";"
	endif
	
	if ( (!(jSc_Ch1on)) %& (!(jSc_Ch2on)) %& (!(jSc_Ch3on)) )
		print "{jSc_setupAIstack} Weird error -- no channel selected for input! At least one checbox must be checked."
		Abort "{jSc_setupAIstack} Weird error -- no channel selected for input! At least one checbox must be checked."
	endif

#ifdef DemoMode
	print "\t\tDemoMode: simulating DAQmx_Scan"
#else
	DAQmx_Scan/DEV=jSc_inDevStr/BKG/ERRH="jSc_AIErrorHookStack()"/EOSH="jSc_AIEndOfScanHookStack()"/AVE=(jSc_pixelBin) WAVES=wStr
//	DAQmx_Scan/DEV=jSc_inDevStr/BKG/ERRH="jSc_AIErrorHookStack()"/EOSH="jSc_AIEndOfScanHookStack()" WAVES=wStr
#endif

End

Function jSc_AIErrorHookStack()
	
	print "{jSc_AIErrorHookStack} Problem while acquiring stack, aborted..."
	jSc_printError()

End

Function jSc_AIEndOfScanHookStack()

	NVAR		jSc_VerboseMode
	
	NVAR		jSc_maxNFrames
	NVAR		jSc_nFrames
	NVAR		jSc_GrabFlag
	NVAR		jSc_frameCounter
	NVAR		jSc_sliceCounter
	NVAR		jSc_nSlices
	NVAR		jSc_averageFrames
	
	NVAR		jSc_GrabStackFlag

	if (jSc_GrabStackFlag==0)
		if (jSc_VerboseMode)
			print "{jSc_AIEndOfScanHookStack} Stack acquisition was already aborted by user -- exiting."
		endif
		Return 1
	endif

	if (jSc_VerboseMode)
		print "{jSc_AIEndOfScanHookStack} End of frame."
	endif
	jSc_frameCounter += 1
	jSc_transferScannedData()
	jSc_transferGrab2storageStack()	
	if (jSc_frameCounter>=jSc_nFrames)
		if (jSc_VerboseMode)
			print "{jSc_AIEndOfScanHookStack} Frame grab done."
		endif
		if (jSc_averageFrames)
			jSc_calcMeanOfSlice()										// Divide sum by number of frames
			jSc_transferAverage2window(jSc_sliceCounter)				// Show the averaged image in the windows at the end of averaging
		endif
		jSc_frameCounter = 0
		jSc_sliceCounter += 1
		if (jSc_sliceCounter>=jSc_nSlices)
			if (jSc_VerboseMode)
				print "{jSc_AIEndOfScanHookStack} Stack grab done."
			endif
			jSc_recoverAfterScan()
			Print "--- Done acquiring stack at time ",time()," ---"
			jSc_saveTIFF(1)
			jSc_Stack_backToStart()
		else
			if (jSc_VerboseMode)
				print "{jSc_AIEndOfScanHookStack} Grabbing next slice in stack."
			endif
			jSc_closeShutter()
			jSc_Stack_nextSlice()
			jSc_openShutter()
			jSc_setupAO()
			jSc_setupAIstack()
		endif
	else
		if (jSc_VerboseMode)
			print "{jSc_AIEndOfScanHookStack} Grabbing next frame in stack."
		endif
		jSc_setupAO()
		jSc_setupAIstack()
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Divide summed up frame by number of frames to get average

Function jSc_calcMeanOfSlice()

	SVAR		jSc_baseName
	NVAR		jSc_suffix
	
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_sliceCounter
	NVAR		jSc_nSlices
	NVAR		jSc_nFrames

	NVAR		jSc_averageFrames
	
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	String		currFile = jSc_baseName+JT_num2digstr(4,jSc_suffix)

	Variable	nChannels = jSc_Ch1on+jSc_Ch2on+jSc_Ch3on
	Variable	nFrames
	Variable	channelCounter = 0

	WAVE		w = $(currFile)	

	if(jSc_Ch1on)
		w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*nChannels+channelCounter] /= jSc_nFrames
		channelCounter += 1
	endif
	if(jSc_Ch2on)
		w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*nChannels+channelCounter] /= jSc_nFrames
		channelCounter += 1
	endif
	if(jSc_Ch3on)
		w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*nChannels+channelCounter] /= jSc_nFrames
		channelCounter += 1
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move back to start of stack

Function jSc_Stack_backToStart()

	NVAR		jSc_stgX_store
	NVAR		jSc_stgY_store
	NVAR		jSc_stgZ_store
	
	NVAR		jSc_ETL_store
	NVAR		jSc_ETLstack
	NVAR		jSc_ETLmicron

	NVAR		jSc_ETLcommand
	NVAR		jSc_ETLmicron

	jSc_COM_MoveTo(jSc_stgX_store,jSc_stgY_store,jSc_stgZ_store)
	print "Moving XYZ stage to start of stack..."
	jSc_COM_WaitUntilMoveDone()
	jSc_COM_getPos()					// Superfluous final read, since jSc_COM_WaitUntilMoveDone already reads pos?
	
	if (jSc_ETLstack)
		print "Moving ETL to start of stack..."
		jSc_ETLmicron = jSc_ETL_store
		jSc_ETLcommand = jSc_MicronToETL(jSc_ETLmicron)
		jSc_updateETLcommand()
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move to next slice in stack

Function jSc_Stack_nextSlice()
	
	NVAR		jSc_sliceCounter
	NVAR		jSc_stkSliceSpacing
	NVAR		jSc_stkStart
	NVAR		jSc_stkEnd

	NVAR		jSc_stgX_store
	NVAR		jSc_stgY_store
	NVAR		jSc_stgZ_store
	
	NVAR		jSc_stkStart
	NVAR		jSc_ETLstack
	NVAR		jSc_ETLcommand
	NVAR		jSc_ETLmicron

	NVAR		jSc_ETLcommand
	NVAR		jSc_ETLmicron

	Variable		direction = 1
	if (jSc_stkStart>jSc_stkEnd)
		direction = -1
	endif
	
	Print "\tSlice #"+JT_num2digstr(4,jSc_sliceCounter)

	if (jSc_ETLstack)
		jSc_ETLmicron = jSc_stkStart+jSc_sliceCounter*jSc_stkSliceSpacing*direction
		jSc_ETLcommand = jSc_MicronToETL(jSc_ETLmicron)
		jSc_updateETLcommand()
	else
		jSc_COM_MoveTo(jSc_stgX_store,jSc_stgY_store,jSc_stgZ_store+jSc_sliceCounter*jSc_stkSliceSpacing*direction)
		jSc_COM_WaitUntilMoveDone()
		jSc_COM_getPos()
	endif
	
End

//////////////////////////////////////////////////////////////////////////////////
//// Loop background task fakes the end-of-scan hook

Function jSc_demoBackProc(s)
	STRUCT WMBackgroundStruct &s
	
	NVAR		jSc_VerboseMode

	if (jSc_VerboseMode)
		print "{jSc_demoBackProc} is faking the end-of-scan hook"
	endif
	dowindow jScanPanel
//	ctrlNamedBackground jSc_demoBack,kill			// Should only execute once
	jSc_AIEndOfScanHook()
	
	return 0

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set up analog input for grab

Function jSc_setupAI()

	SVAR		jSc_inDevStr

	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	NVAR		jSc_vRange1
	NVAR		jSc_vRange2
	NVAR		jSc_vRange3
	
	NVAR		jSc_pixelBin
	
	NVAR		jSc_VerboseMode

	String		wStr = ""

	if (jSc_Ch1on)
		wStr += "jSc_Ch1raw,0,-"+num2str(0)+","+num2str(jSc_vRange1)+";"
	endif
	if (jSc_Ch2on)
		wStr += "jSc_Ch2raw,1,-"+num2str(0)+","+num2str(jSc_vRange2)+";"
	endif
	if (jSc_Ch3on)
		wStr += "jSc_Ch3raw,2,-"+num2str(0)+","+num2str(jSc_vRange3)+";"
	endif

#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: DAQmx_Scan simulated"
	endif
	ctrlNamedBackground jSc_demoBack,period=(60*0.450),proc=jSc_demoBackProc			// Hard-wiring a 450-ms-long frame, deliberately staggering it with the Progress update period
	ctrlNamedBackground jSc_demoBack,start//=(60*0.450)
#else
	DAQmx_Scan/DEV=jSc_inDevStr/BKG/ERRH="jSc_AIErrorHook()"/EOSH="jSc_AIEndOfScanHook()"/AVE=(jSc_pixelBin) WAVES=wStr
#endif

End

Function jSc_AIErrorHook()
	
	print "{jSc_AIErrorHook} Problem during scan, aborted..."
	jSc_printError()

End

Function jSc_AIEndOfScanHook()

	NVAR		jSc_VerboseMode
	
	NVAR		jSc_maxNFrames
	NVAR		jSc_nFrames
	NVAR		jSc_GrabFlag
	NVAR		jSc_frameCounter
	NVAR		jSc_ScanFlag
	
	NVAR		jSc_averageFrames
	
	if (jSc_VerboseMode)
		print "{jSc_AIEndOfScanHook} End of frame."
	endif
	jSc_frameCounter += 1
	jSc_transferScannedData()
	if (jSc_GrabFlag)
		jSc_transferGrab2storage()	
		if (jSc_frameCounter>=jSc_nFrames)
			if (jSc_VerboseMode)
				print "{jSc_AIEndOfScanHook} Frame grab done."
			endif
			jSc_recoverAfterScan()
			if (jSc_averageFrames)
				jSc_calcMeanOfSlice()								// Divide sum by number of frames
				jSc_transferAverage2window(0)						// Show the averaged image in the windows at the end of averaging
			endif
			jSc_saveTIFF(0)
		else
			if (jSc_VerboseMode)
				print "{jSc_AIEndOfScanHook} Grabbing next frame."
			endif
			jSc_setupAO()
			jSc_setupAI()
		endif
	else
		if (jSc_ScanFlag==0)
			if (jSc_VerboseMode)
				print "{jSc_AIEndOfScanHook} Scanning was interrupted."
			endif
			jSc_recoverAfterScan()
		else
			if (jSc_frameCounter>=jSc_maxNFrames)
				if (jSc_VerboseMode)
					print "{jSc_AIEndOfScanHook} maxNFrames was reached."
				endif
				jSc_recoverAfterScan()
			else
				if (jSc_VerboseMode)
					print "{jSc_AIEndOfScanHook} Scanning next frame."
				endif
				jSc_setupAO()
				jSc_setupAI()
			endif
		endif
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Initialize stack storage matrix before grabbing stack

Function jSc_initGrabStackStorage()

	SVAR		jSc_baseName
	NVAR		jSc_suffix
	
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_nFrames
	NVAR		jSc_nSlices

	NVAR		jSc_averageFrames
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	String		currFile = jSc_baseName+JT_num2digstr(4,jSc_suffix)

	Variable	nChannels = jSc_Ch1on+jSc_Ch2on+jSc_Ch3on
	Variable	nFrames			// Nasty nomenclature warning: nFrames is the number of slices in the stack to be saved, so not like jSc_nFrames (number of frames to average per slice)
	if (jSc_averageFrames)
		nFrames = nChannels*jSc_nSlices
	else
		nFrames = nChannels*jSc_nFrames*jSc_nSlices
	endif
	
	Make/D/O/N=(jSc_pxpl,jSc_lnpf,nFrames) $(currFile)
	WAVE	w =  $(currFile)
	w = 0

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Initialize storage matrix before grab

Function jSc_initGrabStorage()

	SVAR		jSc_baseName
	NVAR		jSc_suffix
	
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_nFrames

	NVAR		jSc_averageFrames
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	NVAR		jSc_BurstFrames
	NVAR		jSc_nBurstFrames
	
	String		currFile = jSc_baseName+JT_num2digstr(4,jSc_suffix)

	Variable		nChannels = jSc_Ch1on+jSc_Ch2on+jSc_Ch3on
	Variable		nFrames			// Nasty nomenclature warning: nFrames is the number of slices in the stack to be saved, so not like jSc_nFrames (number of frames to average per slice)
	if (jSc_averageFrames)
		nFrames = nChannels
	else
		nFrames = nChannels*jSc_nFrames
	endif
	
	if (jSc_BurstFrames)
		nFrames *= jSc_nBurstFrames
	endif
	
	Make/D/O/N=(jSc_pxpl,jSc_lnpf,nFrames) $(currFile)
	WAVE	w = $(currFile)
	w = 0
	
	if (jSc_BurstFrames)			// Should have executed well before this, but just to be on the safe side
		jSc_makeBurstFrames()
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Transfer acquired frames to storage

Function jSc_transferGrab2storage()

	SVAR		jSc_baseName
	NVAR		jSc_suffix
	
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_nFrames
	NVAR		jSc_frameCounter

	NVAR		jSc_averageFrames
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	WAVE		ch1image
	WAVE		ch2image
	WAVE		ch3image
	
	WAVE		ch1imageBurst
	WAVE		ch2imageBurst
	WAVE		ch3imageBurst
	
	NVAR		jSc_BurstFrames
	NVAR		jSc_nBurstFrames

	String		currFile = jSc_baseName+JT_num2digstr(4,jSc_suffix)

	Variable	nChannels = jSc_Ch1on+jSc_Ch2on+jSc_Ch3on
	Variable	channelCounter = 0
	
	Variable	i
	
	WAVE		w = $(currFile)
	if (jSc_averageFrames)

		if (jSc_BurstFrames)

			i = 0
			do
				if(jSc_Ch1on)
					w[0,jSc_pxpl-1][0,jSc_lnpf-1][channelCounter] += ch1imageBurst[p][q][i]
					channelCounter += 1
				endif
				if(jSc_Ch2on)
					w[0,jSc_pxpl-1][0,jSc_lnpf-1][channelCounter] += ch2imageBurst[p][q][i]
					channelCounter += 1
				endif
				if(jSc_Ch3on)
					w[0,jSc_pxpl-1][0,jSc_lnpf-1][channelCounter] += ch3imageBurst[p][q][i]
					channelCounter += 1
				endif
				i += 1
			while(i<jSc_nBurstFrames)
		
		else
	
			if(jSc_Ch1on)
				w[0,jSc_pxpl-1][0,jSc_lnpf-1][channelCounter] += ch1image[p][q]
				channelCounter += 1
			endif
			if(jSc_Ch2on)
				w[0,jSc_pxpl-1][0,jSc_lnpf-1][channelCounter] += ch2image[p][q]
				channelCounter += 1
			endif
			if(jSc_Ch3on)
				w[0,jSc_pxpl-1][0,jSc_lnpf-1][channelCounter] += ch3image[p][q]
				channelCounter += 1
			endif
			
		endif
		
	else
	
		if (jSc_BurstFrames)
		
			i = 0
			do

				if(jSc_Ch1on)
					w[0,jSc_pxpl-1][0,jSc_lnpf-1][ (jSc_frameCounter-1)*nChannels*jSc_nBurstFrames + channelCounter] = ch1imageBurst[p][q][i]
					channelCounter += 1
				endif
				if(jSc_Ch2on)
					w[0,jSc_pxpl-1][0,jSc_lnpf-1][ (jSc_frameCounter-1)*nChannels*jSc_nBurstFrames + channelCounter] = ch2imageBurst[p][q][i]
					channelCounter += 1
				endif
				if(jSc_Ch3on)
					w[0,jSc_pxpl-1][0,jSc_lnpf-1][ (jSc_frameCounter-1)*nChannels*jSc_nBurstFrames + channelCounter] = ch3imageBurst[p][q][i]
					channelCounter += 1
				endif

				i += 1
			while(i<jSc_nBurstFrames)

		else
		
			if(jSc_Ch1on)
				w[0,jSc_pxpl-1][0,jSc_lnpf-1][ (jSc_frameCounter-1)*nChannels + channelCounter] = ch1image[p][q]
				channelCounter += 1
			endif
			if(jSc_Ch2on)
				w[0,jSc_pxpl-1][0,jSc_lnpf-1][ (jSc_frameCounter-1)*nChannels + channelCounter] = ch2image[p][q]
				channelCounter += 1
			endif
			if(jSc_Ch3on)
				w[0,jSc_pxpl-1][0,jSc_lnpf-1][ (jSc_frameCounter-1)*nChannels + channelCounter] = ch3image[p][q]
				channelCounter += 1
			endif

		endif

	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Transfer acquired frames to storage for a stack

Function jSc_transferGrab2storageStack()

	SVAR		jSc_baseName
	NVAR		jSc_suffix
	
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_nFrames
	NVAR		jSc_frameCounter
	NVAR		jSc_nSlices
	NVAR		jSc_sliceCounter

	NVAR		jSc_averageFrames
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	WAVE		ch1image
	WAVE		ch2image
	WAVE		ch3image
	
	String		currFile = jSc_baseName+JT_num2digstr(4,jSc_suffix)

	Variable	nChannels = jSc_Ch1on+jSc_Ch2on+jSc_Ch3on
	Variable	channelCounter = 0
	
	WAVE		w = $(currFile)
	if (jSc_averageFrames)
		if(jSc_Ch1on)
			w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*nChannels+channelCounter] += ch1image[p][q]
			channelCounter += 1
		endif
		if(jSc_Ch2on)
			w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*nChannels+channelCounter] += ch2image[p][q]
			channelCounter += 1
		endif
		if(jSc_Ch3on)
			w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*nChannels+channelCounter] += ch3image[p][q]
			channelCounter += 1
		endif
	else
		if(jSc_Ch1on)
			w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*(jSc_frameCounter-1)*nChannels+channelCounter] = ch1image[p][q]
			channelCounter += 1
		endif
		if(jSc_Ch2on)
			w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*(jSc_frameCounter-1)*nChannels+channelCounter] = ch2image[p][q]
			channelCounter += 1
		endif
		if(jSc_Ch3on)
			w[0,jSc_pxpl-1][0,jSc_lnpf-1][(jSc_sliceCounter-0)*(jSc_frameCounter-1)*nChannels+channelCounter] = ch3image[p][q]
			channelCounter += 1
		endif
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// At the end of averaging, transfer averaged frame to shown images

Function jSc_transferAverage2window(jSc_sliceCounter)
	Variable	jSc_sliceCounter

	SVAR		jSc_baseName
	NVAR		jSc_suffix
	
	NVAR		jSc_VerboseMode
	
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_nFrames
	NVAR		jSc_frameCounter

	NVAR		jSc_averageFrames
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	WAVE		ch1image
	WAVE		ch2image
	WAVE		ch3image
	
	String		currFile = jSc_baseName+JT_num2digstr(4,jSc_suffix)

	Variable	nChannels = jSc_Ch1on+jSc_Ch2on+jSc_Ch3on
	Variable	channelCounter = 0
	
	WAVE		w = $(currFile)
	if(jSc_Ch1on)
		ch1image[0,jSc_pxpl-1][0,jSc_lnpf-1] = w[p][q][jSc_sliceCounter*nChannels+channelCounter]
		channelCounter += 1
		jSc_updateLUT(1)
	endif
	if(jSc_Ch2on)
		ch2image[0,jSc_pxpl-1][0,jSc_lnpf-1] = w[p][q][jSc_sliceCounter*nChannels+channelCounter]
		channelCounter += 1
		jSc_updateLUT(2)
	endif
	if(jSc_Ch3on)
		ch3image[0,jSc_pxpl-1][0,jSc_lnpf-1] = w[p][q][jSc_sliceCounter*nChannels+channelCounter]
		channelCounter += 1
		jSc_updateLUT(3)
	endif
	
	if (jSc_VerboseMode)
		print "{jSc_transferAverage2window} Transferring averaged data back to windows."
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Save grabbed image as TIFF file

Function jSc_saveTIFF(isStack)
	Variable	isStack

	SVAR		jSc_baseName
	NVAR		jSc_suffix
	
	String		currFile = jSc_baseName+JT_num2digstr(4,jSc_suffix)
	
	SVAR		jSc_rig

	NVAR		jSc_nFrames
	NVAR		jSc_frameCounter

	NVAR		jSc_nBurstFrames
	NVAR		jSc_burstFrames

	NVAR		jSc_scanAngle
	NVAR		jSc_mspl
	NVAR		jSc_totmspl
	NVAR		jSc_corrtotmspl
	NVAR		jSc_actualFPS
	NVAR		jSc_actualSampFreq
	NVAR		jSc_flyback
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	NVAR		jSc_xPad
	
	NVAR		jSc_averageFrames
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ

	WAVE		ch1image
	WAVE		ch2image
	WAVE		ch3image
	
	NVAR		jSc_LSflag

	NVAR		jSc_sliceCounter
	NVAR		jSc_nSlices
	NVAR		jSc_ETLstack
	
	NVAR		jSc_stkStart
	NVAR		jSc_stkEnd
	NVAR		jSc_nSlices
	NVAR		jSc_stkSliceSpacing
	
	jSc_COM_getPos()															// Refresh XYZ stage coordinates
	jSc_calcCorrectedmspl()														// Calculate the actual sampling frequency

	Redimension/U/W $(currFile)													// Convert from double precision float to unsigned 16-bit integer

	String/G	jSC_tiffTagStr = ""
	jSC_tiffTagStr += "jScan (c) Jesper Sjostrom 2013\r"
	jSC_tiffTagStr += "rig="+jSc_rig+"\r"
	jSC_tiffTagStr += "linescan="+num2str(jSc_LSflag)+"\r"
	jSC_tiffTagStr += "scanAngle="+num2str(jSc_scanAngle)+"\r"
	jSC_tiffTagStr += "mspl="+num2str(jSc_mspl)+"\r"
	jSC_tiffTagStr += "totmspl="+num2str(jSc_totmspl)+"\r"
	jSC_tiffTagStr += "corrmspl="+num2str(jSc_corrtotmspl)+"\r"
	jSC_tiffTagStr += "actualSampFreq="+num2str(jSc_actualSampFreq)+"\r"
	jSC_tiffTagStr += "actualFPS="+num2str(jSc_actualFPS)+"\r"
	jSC_tiffTagStr += "flyback="+num2str(jSc_flyback)+"\r"
	jSC_tiffTagStr += "pxpl="+num2str(jSc_pxpl)+"\r"
	jSC_tiffTagStr += "lnpf="+num2str(jSc_lnpf)+"\r"
	jSC_tiffTagStr += "xAmp="+num2str(jSc_xAmp)+"\r"
	jSC_tiffTagStr += "yAmp="+num2str(jSc_yAmp)+"\r"
	jSC_tiffTagStr += "xPad="+num2str(jSc_xPad)+"\r"
	jSC_tiffTagStr += "Ch1on="+num2str(jSc_Ch1on)+"\r"
	jSC_tiffTagStr += "Ch2on="+num2str(jSc_Ch2on)+"\r"
	jSC_tiffTagStr += "Ch3on="+num2str(jSc_Ch3on)+"\r"
	jSC_tiffTagStr += "averageFrames="+num2str(jSc_averageFrames)+"\r"			// Boolean: Were frames averaged?
	jSC_tiffTagStr += "nFrames="+num2str(jSc_nFrames)+"\r"						// Number of frames in acquisition
	jSC_tiffTagStr += "frameCounter="+num2str(jSc_frameCounter)+"\r"			// Number of frames that were actually acquired (could be interrupted acquisition)
	
	jSC_tiffTagStr += "burstFrames="+num2str(jSc_burstFrames)+"\r"				// Boolean: Burst frames mode?
	jSC_tiffTagStr += "nBurstFrames="+num2str(jSc_nBurstFrames)+"\r"				// Number of burst frames in acquisition

	jSC_tiffTagStr += "date="+Secs2Date(DateTime,-2)+"\r"
	jSC_tiffTagStr += "time="+Secs2Time(DateTime,3)+"\r"
	jSC_tiffTagStr += "stgX="+num2str(jSc_stgX)+"\r"
	jSC_tiffTagStr += "stgY="+num2str(jSc_stgY)+"\r"
	jSC_tiffTagStr += "stgZ="+num2str(jSc_stgZ)+"\r"
	// Stack parameters (may contain jibberish if isStack is False, i.e. not a stack)
	jSC_tiffTagStr += "isStack="+num2str(isStack)+"\r"							// Boolean: Is this a stack?
	jSC_tiffTagStr += "ETLstack="+num2str(jSc_ETLstack)+"\r"					// Boolean: Is stack acquired with ETL? (otherwise with stage)
	jSC_tiffTagStr += "nSlices="+num2str(jSc_nSlices)+"\r"						// Number of slices in stack
	jSC_tiffTagStr += "sliceCounter="+num2str(jSc_sliceCounter)+"\r"			// Number of slices in stack that were actually acquired (could be interrupted acquisition)
	jSC_tiffTagStr += "stkStart="+num2str(jSc_stkStart)+"\r"					// Start of stack in µm (identical to jSc_stgZ if ETLstack is False)
	jSC_tiffTagStr += "stkEnd="+num2str(jSc_stkEnd)+"\r"							// End of stack in µm
	jSC_tiffTagStr += "jSc_stkSliceSpacing="+num2str(jSc_stkSliceSpacing)+"\r"	// Stack spacing in µm

	
	Make/T/O/N=(1,5) jSc_Tags
	jSc_Tags[0][0] = "270"														// Tag number
	jSc_Tags[0][1] = "IMAGEDESCRIPTION"											// Tag description
	jSc_Tags[0][2] = "2"														// Type: ASCII
	jSc_Tags[0][3] = Num2Str(StrLen(jSC_tiffTagStr)+1)							// Data length plus space for NUL byte
	jSc_Tags[0][4] = jSC_tiffTagStr+"\0"										// String TIFF tags must end with NUL byte

	ImageSave/U/O/IGOR/D=16/S/T="tiff"/P=jScPath/WT=jSc_Tags $(currFile) as currFile+".tif"
	print Time()+":\tSaved \""+currFile+".tif\""
	
	KillWaves/Z $(currFile)
	
	jSc_suffix += 1
	
	if (jSc_suffix>9999)
		jSc_suffix = 1
		Beep
		print "WARNING! Suffix numbering just wrapped around from 9999 to 1! Files may be overwritten!"
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Transfer scanned data from raw data waves to image windows for all channels

Function jSc_transferScannedData()

	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on
	
	Variable	thisChannelWasAcquired = 0			// jSc_readChBoxProc ensures that at least one channel is acquired
	
	if (jSc_Ch1on)
		jSc_raw2image(1)	//,0)
		jSc_updateLUT(1)
		thisChannelWasAcquired = 1
	endif
	if (jSc_Ch2on)
		jSc_raw2image(2)	//,0)
		jSc_updateLUT(2)
		thisChannelWasAcquired = 2
	endif
	if (jSc_Ch3on)
		jSc_raw2image(3)	//,0)
		jSc_updateLUT(3)
		thisChannelWasAcquired = 3
	endif
	
	if (thisChannelWasAcquired == 0)				// This should never happen, but catch it anyway
		print "Strange error in {jSc_transferScannedData}: No channel was acquired?"
		Abort "Strange error in {jSc_transferScannedData}: No channel was acquired?"
	endif
	
End

//// This function does the actual transfer of scanned data from raw data waves to a specific image window channel

Function	jSc_raw2image(theChannel)
	Variable	theChannel
	
	NVAR		jSc_BoardBitScaling

	NVAR		jSc_pixelBin
	WAVE		theSource = $("jSc_Ch"+num2str(theChannel)+"raw")
	WAVE		theDest = $("ch"+num2str(theChannel)+"image")
	WAVE		theDestBurst = $("ch"+num2str(theChannel)+"imageBurst")
	WAVE		jSc_xRaster,jSc_yRaster
	
	NVAR		jSc_mspl
	NVAR		jSc_flyback
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	NVAR		jSc_xPad
	
	NVAR		jSc_nSampPrPad
	NVAR		jSc_nSampPrLn
	NVAR		jSc_nSampPrFlyback
	NVAR		jSc_tot_nSampPrLn
	NVAR		jSc_nSamples
	NVAR		jSc_mspf

	NVAR		jSc_LSflag

	NVAR		vRange = $("jSc_vRange"+num2str(theChannel))
	
	NVAR		jSc_BurstFrames
	NVAR		jSc_nBurstFrames
//	WAVE		ch1imageBurst
//	WAVE		ch2imageBurst
//	WAVE		ch3imageBurst

	theSource = theSource[p] < 0 ? 0 : theSource[p]						// Don't allow negative values (Should I really do this?)

	Variable	whichFrame = 0											// In burstFrames mode, pick only one frame for the viewer windows (future: do max intensity projection instead)
	if (jSc_BurstFrames)
		whichFrame = jSc_nBurstFrames-1
	endif

	Variable	i,j
	i = 0
	do
#ifdef DemoMode
		if (jSc_LSflag)
			theDest[0,jSc_pxpl-1][i] = jSc_BoardBitScaling*sqrt(Besselj(0,Pi*6*sqrt((p-jSc_nSampPrLn/2)^2/jSc_nSampPrLn^2))^2)
		else
			theDest[0,jSc_pxpl-1][i] = jSc_BoardBitScaling*sqrt(Besselj(0,Pi*6*sqrt((p-jSc_nSampPrLn/2)^2/jSc_nSampPrLn^2+(q-jSc_lnpf/2)^2/jSc_lnpf^2))^2)	// First-kind Bessel to have something to look at
		endif
		theDest[0,jSc_pxpl-1][i] += abs(gnoise(0.1)*jSc_BoardBitScaling)
#else
		if (jSc_BurstFrames)	// In burstFrames mode, transfer all jSc_nBurstFrames frames in one go
			j = 0
			do
				theDestBurst[0,jSc_pxpl-1][i][j] = theSource[j*jSc_nSamples + p + i*(jSc_tot_nSampPrLn)+jSc_nSampPrPad]/vRange*jSc_BoardBitScaling		// Non-zero j means pick last frame in a burst
				j += 1
			while(j<jSc_nBurstFrames)
		endif
		// theDest always needs a data from theSource, even during burstFrames mode, since this is what is displayed in the channel windows
		theDest[0,jSc_pxpl-1][i] = theSource[whichFrame*jSc_nSamples + p + i*(jSc_tot_nSampPrLn)+jSc_nSampPrPad]/vRange*jSc_BoardBitScaling		// Non-zero whichFrame means pick last frame in a burst
#endif
		i += 1
	while(i<jSc_lnpf)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Dump parameters

Function jSc_dumpParams()

	NVAR		jSc_mspl
	NVAR		jSc_totmspl
	NVAR		jSc_flyback
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	NVAR		jSc_xPad
	
	NVAR		jSc_nSampPrPad
	NVAR		jSc_nSampPrLn
	NVAR		jSc_nSampPrFlyback
	NVAR		jSc_tot_nSampPrLn
	NVAR		jSc_nSamples
	NVAR		jSc_mspf
	NVAR		jSc_pixelBin

	NVAR		jSc_corrtotmspl
	NVAR		jSc_actualSampFreq
	NVAR		jSc_actualFPS

	WAVE		jSc_Ch1raw

	print "--- Parameter dump ---"	
	print "Date:",date()
	print "Time:",time()

	print "jSc_mspl",jSc_mspl
	print "jSc_flyback",jSc_flyback
	print "jSc_pxpl",jSc_pxpl
	print "jSc_lnpf",jSc_lnpf
	print "jSc_xAmp",jSc_xAmp
	print "jSc_yAmp",jSc_yAmp
	print "jSc_xPad",jSc_xPad
	print "-"
	print "jSc_nSampPrPad",jSc_nSampPrPad
	print "jSc_nSampPrLn",jSc_nSampPrLn
	print "jSc_nSampPrFlyback",jSc_nSampPrFlyback
	print "jSc_tot_nSampPrLn",jSc_tot_nSampPrLn
	print "jSc_nSamples",jSc_nSamples
	print "jSc_mspf",jSc_mspf
	print "Actual sampling frequency (Hz) -- 1/dimdelta(jSc_Ch1raw,0)",jSc_actualSampFreq		// WARNING! jSc_actualSampFreq must be extracted right after an acquisition
	Variable	calcSampFreq = 1/dimdelta(jSc_xRaster,0)/jSc_pixelBin
	print "Calculated sampling frequency (Hz) -- 1/dimdelta(jSc_xRaster,0)",calcSampFreq
	print "\tDiscrepancy (%)",100-jSc_actualSampFreq/calcSampFreq*100
	print "Correct jSc_totmspl (ms)",jSc_corrtotmspl
	print "Actual frames per second (Hz)",jSc_actualFPS
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Begin waveform generation

Function jSc_setupAO()

	SVAR		jSc_outDevStr
	SVAR		jSc_inDevStr
	WAVE		jSc_xRaster,jSc_yRaster
	
	NVAR		jSc_VerboseMode
	
	String/G		jSc_AOString = ""
	jSc_AOString += "jSc_xRaster, 0;"
	jSc_AOString += "jSc_yRaster, 1;"
	
#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: DAQmx_WaveformGen simulated"
	endif
#else
	DAQmx_WaveformGen/DEV=jSc_outDevStr/ERRH="jSc_AOErrorHook()"/NPRD=1/TRIG={"/"+jSc_inDevStr+"/ai/starttrigger"}/CLK={"/"+jSc_inDevStr+"/ai/sampleclock",1} jSc_AOString
#endif

End

Function jSc_AOErrorHook()
	
	print "{jSc_AOErrorHook} Problem during waveform generation, aborted..."
	jSc_printError()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make raster input data
//// NOTE! jSc_makeAIRasterData has to execute right after jSc_makeAORasterData!

Function jSc_makeAIRasterData()

	NVAR		jSc_nSamples
	NVAR		jSc_mspf
	
	NVAR		jSc_BurstFrames
	NVAR		jSc_nBurstFrames

	Make/O/N=(jSc_nSamples) jSc_Ch1raw,jSc_Ch2raw,jSc_Ch3raw
	SetScale/I x 0,jSc_mspf*1e-3,"s", jSc_Ch1raw,jSc_Ch2raw,jSc_Ch3raw
	SetScale d 0,0,"V", jSc_Ch1raw,jSc_Ch2raw,jSc_Ch3raw
	// Ensure a perfect match between rightx(jSc_xRaster) and rightx(jSc_Ch1raw) etc
	// But jSc_AIEndOfScanHook should ideally execute after jSc_AOEndOfScanHook -- could the below kludge ensure this?
//	InsertPoints numpnts(jSc_Ch1raw), 10, jSc_Ch1raw,jSc_Ch2raw,jSc_Ch3raw

	// If burst-frames mode, repeat the input waves n = jSc_nBurstFrames number of times
	if (jSc_BurstFrames)
		String		ConcatStr1 = ""
		String		ConcatStr2 = ""
		String		ConcatStr3 = ""
		variable	i = 0
		do
			ConcatStr1 += "jSc_Ch1raw;"
			ConcatStr2 += "jSc_Ch2raw;"
			ConcatStr3 += "jSc_Ch3raw;"
			i += 1
		while(i<jSc_nBurstFrames)
		Concatenate/O/NP ConcatStr1,wTemp
		Duplicate/O wTemp,jSc_Ch1raw
		Concatenate/O/NP ConcatStr2,wTemp
		Duplicate/O wTemp,jSc_Ch2raw
		Concatenate/O/NP ConcatStr3,wTemp
		Duplicate/O wTemp,jSc_Ch3raw
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make raster output data

Function jSc_makeAORasterData()

	NVAR		jSc_mspl
	NVAR		jSc_flyback
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	NVAR		jSc_xPad
	NVAR		jSc_pixelBin
	
	NVAR		jSc_ZoomFactor

	NVAR		jSc_LSflag

	NVAR		jSc_BurstFrames
	NVAR		jSc_nBurstFrames

	// Note to self: jSc_xPad has to be treated as an absolute value, since it is a form of padding; negative padding makes no sense.
	// Yet, xTotSwing has to inherit sign of jSc_xAmp, otherwise the user cannot invert the scanning to mirror the image
	Variable	xTotSwing = 2*sign(jSc_xAmp)*(abs(jSc_xAmp)+jSc_xPad)/jSc_ZoomFactor
	Variable	yTotSwing = 2*jSc_yAmp/jSc_ZoomFactor
	
	Variable/G	jSc_nSampPrPad = Round(jSc_xPad/abs(jSc_xAmp)*jSc_pxpl)
	Variable/G	jSc_nSampPrLn = jSc_pxpl + jSc_nSampPrPad
	Variable/G	jSc_nSampPrFlyback = Round(jSc_flyback/jSc_mspl*jSc_nSampPrLn)
	Variable/G	jSc_tot_nSampPrLn = jSc_nSampPrLn + jSc_nSampPrFlyback
	Variable/G	jSc_nSamples = jSc_tot_nSampPrLn * jSc_lnpf			// The number of samples per frame
	Variable/G	jSc_mspf = (jSc_mspl+jSc_flyback)*jSc_lnpf
	
	Variable	k = xTotSwing/jSc_nSampPrLn
	Variable	m = -xTotSwing/2
	
	Variable	k_flyback = -xTotSwing/(jSc_nSampPrFlyback-1)
	Variable	m_flyback = xTotSwing/2
	
	Variable	ky = yTotSwing/(jSc_lnpf-1)
	Variable	my = -yTotSwing/2
	
	Variable	ky_slow = ky/jSc_nSampPrFlyback
	Variable	my_slow = -yTotSwing/2
	
	Variable	ky_flyback = -yTotSwing/(jSc_nSampPrFlyback-1)
	Variable	my_flyback = yTotSwing/2
	
	Make/O/N=(jSc_nSamples) jSc_xRaster,jSc_yRaster

	Variable	i
	i = 0
	do
		jSc_xRaster[i*jSc_tot_nSampPrLn,i*jSc_tot_nSampPrLn+jSc_nSampPrLn-1] = k*(p-i*jSc_tot_nSampPrLn)+m		// forward scan
		jSc_xRaster[i*jSc_tot_nSampPrLn+jSc_nSampPrLn,i*jSc_tot_nSampPrLn+jSc_tot_nSampPrLn-1] = k_flyback*(p-i*jSc_tot_nSampPrLn-jSc_nSampPrLn)+m_flyback	// fly back
		jSc_yRaster[i*jSc_tot_nSampPrLn,i*jSc_tot_nSampPrLn+jSc_nSampPrLn-1] = ky*i+my		// y sits still on specific line
		if (i==jSc_lnpf-1)			// y flies back to start at the last line
			jSc_yRaster[i*jSc_tot_nSampPrLn+jSc_nSampPrLn,i*jSc_tot_nSampPrLn+jSc_tot_nSampPrLn-1] = ky_flyback*(p-i*jSc_tot_nSampPrLn-jSc_nSampPrLn)+my_flyback
		else							// y flies to next line otherwise
			jSc_yRaster[i*jSc_tot_nSampPrLn+jSc_nSampPrLn,i*jSc_tot_nSampPrLn+jSc_tot_nSampPrLn-1] = ky_slow*(p-i*jSc_nSampPrLn-jSc_nSampPrLn)+my_slow
		endif
		i += 1
	while(i<jSc_lnpf)
	
	if (jSc_LSflag)
		jSc_yRaster = 0
	endif

	SetScale/I x 0,jSc_mspf*1e-3,"s", jSc_xRaster,jSc_yRaster
	SetScale d 0,0,"V", jSc_xRaster,jSc_yRaster
	
	// NOTE! Should I do this or not???
	Smooth/E=1/B 5,jSc_xRaster,jSc_yRaster
	
	// Upsample output to account for output running on input sampling frequency, but input may be binned
	Resample/UP=(jSc_pixelBin) jSc_xRaster,jSc_yRaster
	if (jSc_pixelBin>1)	// Resampling loses jSc_pixelBin-1 points at the end, so insert the last point several times
		InsertPoints/V=(jSc_xRaster[numpnts(jSc_xRaster)-1]) numpnts(jSc_xRaster),jSc_pixelBin-1,jSc_xRaster
		InsertPoints/V=(jSc_yRaster[numpnts(jSc_yRaster)-1]) numpnts(jSc_yRaster),jSc_pixelBin-1,jSc_yRaster
	endif

	// If burst-frames mode, repeat the output waves n = jSc_nBurstFrames number of times
	if (jSc_BurstFrames)
		String	ConcatStr1 = ""
		String	ConcatStr2 = ""
		i = 0
		do
			ConcatStr1 += "jSc_xRaster;"
			ConcatStr2 += "jSc_yRaster;"
			i += 1
		while(i<jSc_nBurstFrames)
		Concatenate/O/NP ConcatStr1,wTemp
		Duplicate/O wTemp,jSc_xRaster
		Concatenate/O/NP ConcatStr2,wTemp
		Duplicate/O wTemp,jSc_yRaster
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Draw images

Function jSc_drawImages()

	Variable/G	jSc_imCounter = 0
	
	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on

	jSc_killimages()
	
	if (jSc_Ch1on)
		jSc_drawOneImage(1)
		jSc_imCounter = 1
	endif

	if (jSc_Ch2on)
		jSc_drawOneImage(2)
		jSc_imCounter = 2
	endif

	if (jSc_Ch3on)
		jSc_drawOneImage(3)
	endif
	
	jSc_setImageAspectRatio()

End

Function jSc_drawOneImage(which)
	Variable		which

	NVAR		jSc_imSize
	NVAR		jSc_imCounter
	NVAR		jSc_yAmp
	NVAR		jSc_xAmp
	
	Variable	ScSc = PanelResolution("")/ScreenResolution

	Variable	xPos = 292+28
	Variable	yPos = 50
	Variable	Width = jSc_imSize
	Variable	Height = Width

	Variable	xSize = JT_ScreenSize(0)
	Variable	ySize = JT_ScreenSize(1)
	Variable	drawRow = 1
	if (ySize>xSize)
		drawRow = 0
	endif

	DoWindow /K $("jSc_ImageViewer"+num2str(which))
	Display /W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width,yPos*ScSc+Height) as "Channel "+num2str(which)
	DoWindow /C $("jSc_ImageViewer"+num2str(which))
	AppendImage /T $("ch"+num2str(which)+"image")

	ModifyGraph margin(left)=14,margin(bottom)=14,margin(top)=14,margin(right)=14
	ModifyGraph mirror=2
	ModifyGraph nticks=6
	ModifyGraph minor=1
	ModifyGraph fSize=9
	ModifyGraph standoff=0
	ModifyGraph tkLblRot(left)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
	SetAxis/A/R left

	if (jSc_imCounter>0)
		if (drawRow)
			AutoPositionWindow/E/M=0/R=$("jSC_ImageViewer"+num2str(jSc_imCounter)) $("jSC_ImageViewer"+num2str(which))
		else
			AutoPositionWindow/E/M=1/R=$("jSC_ImageViewer"+num2str(jSc_imCounter)) $("jSC_ImageViewer"+num2str(which))
		endif
	else
		AutoPositionWindow/E/M=0/R=jScanPanel $("jSC_ImageViewer"+num2str(which))
	endif

	Variable	xx = 8
	Variable	yy = 2
	Variable	xSkip = 100
	Variable	h = 21
	Variable	fontSize=11
	NVAR	storedPopVal = $("jSc_LUTno"+num2str(which))
	ControlBar 25
	PopupMenu $("LUTpop"+num2str(which)),pos={xx,yy},size={xSkip,h},bodyWidth=(xSkip-24),proc=jSc_changeLUTProc,title="LUT: ",font="Arial",fSize=fontSize
	PopupMenu $("LUTpop"+num2str(which)),mode=storedPopVal,value= #"\"*COLORTABLEPOPNONAMES*\""
	xx += xSkip+4
	xSkip = 80
	SetVariable $("LUTstart"+num2str(which)+"SV"),pos={xx,yy},size={xSkip,h},title="start: ",value=$("jSc_LUTstart"+num2str(which)),proc=jSc_setLUTwindowProc,limits={0,65535,100},fsize=fontSize,font="Arial"
	xx += xSkip+4
	SetVariable $("LUTend"+num2str(which)+"SV"),pos={xx,yy},size={xSkip,h},title="end: ",value=$("jSc_LUTend"+num2str(which)),proc=jSc_setLUTwindowProc,limits={0,65535,100},fsize=fontSize,font="Arial"
	xx += xSkip+4
	NVAR	storedCheckVal = $("jSc_LUTauto"+num2str(which))
	CheckBox $("autoLUT"+num2str(which)),pos={xx,yy+2},title="auto",proc=jSc_readAutoLUTChBoxProc,value=storedCheckVal,fsize=fontSize,font="Arial"

	doUpdate
	jSc_updateLUT(which)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Resize the LUT window

Function jSc_setLUTwindowProc(ctrlName,varNum,varStr,varName) : SetVariableControl
	String		ctrlName
	Variable		varNum
	String		varStr
	String		varName
	
	variable		startFlag = StringMatch(ctrlName[3,3],"s")
	variable		channel
	if (startFlag)
		channel = str2num(ctrlName[8,8])
	else
		channel = str2num(ctrlName[6,6])
	endif
	
	// If user sets the LUT range, then the 'auto' checkbox should presumably be unchecked too
	NVAR	storedCheckVal = $("jSc_LUTauto"+num2str(channel))
	storedCheckVal = 0
	CheckBox $("autoLUT"+num2str(channel)),value=storedCheckVal,win=$("jSC_ImageViewer"+num2str(channel))
	ControlUpdate/W=$("jSC_ImageViewer"+num2str(channel)) $("autoLUT"+num2str(channel))
	
	jSc_updateLUT(channel)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read and store auto-LUT checkbox values from image windows

Function jSc_readAutoLUTChBoxProc(ctrlName,checked) : CheckBoxControl
	String	ctrlName
	Variable	checked
	
	Variable	channel = str2num(ctrlName[7,7])
	
	if (checked)
		print "Channel #"+num2str(channel)+" auto-LUT was checked."
	else
		print "Channel #"+num2str(channel)+" auto-LUT was unchecked."
	endif
	
	NVAR	storedCheckVal = $("jSc_LUTauto"+num2str(channel))

	storedCheckVal = checked
	
	jSc_updateLUT(channel)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pick channel to be used for selecting 2p zap positions

Function jSc_PickChannelProc(ctrlName,popNum,popStr) : PopupMenuControl
	String	ctrlName
	Variable	popNum
	String	popStr
	
	if (Exists("jSc_pointsX")==0)
		Make/O/N=(0) jSc_pointsX,jSc_pointsY,jSc_pointsZ,jSc_pointsN
	endif
	if (Exists("jSc_xVw")==0)
		Make/O/N=(0) jSc_yVw,jSc_xVw,jSc_zVw
	endif
	
	Variable/G	jSc_pickedFromStack = 0							// Boolean: enable picking and zapping cells in ETL stack
	Variable/G	jSc_pickedChannel = mod(popNum,3)
	
	if (popNum<4)
		print "Getting channel "+num2str(jSc_pickedChannel)+" from most recently scanned image."
		jSc_pickedFromStack = 0									// Boolean: Not picked from ETL stack
		Duplicate/O $("ch"+num2str(jSc_pickedChannel)+"image"),jSc_2pZap_image	// Pick channel from most recently acquired data
		jSc_draw2pZapImage(jSc_pickedChannel)					// Draw the 2p Zap image window
	else
		print "Getting channel "+num2str(jSc_pickedChannel)+" from saved stack of choice."
		jSc_load2pZapStack()										// Pick entire stack from file saved on HD
		jSc_pickedFromStack = 1									// Boolean: Picked from ETL stack, important that this is set /after/ jSc_load2pZapStack has executed, in case of errors loading
		Variable/G	jSc_LS_sliceNo = 0							// Default to the first slice in the just loaded stack
		jSc_pickSliceFor2pZapImage()							// Pick slice from stack
		jSc_draw2pZapImage(jSc_pickedChannel)					// Draw the 2p Zap image window
	endif
		
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pick stack channel to be loaded for selecting 2p zap positions

Function jSc_pickSliceFor2pZapImage()
	
	NVAR		jSc_LS_nChannels
	NVAR		jSc_LS_sliceNo
	NVAR		jSc_pickedChannel
	
	WAVE		imSource = jSc_2pZapStackRAW
	WAVE		imDest = $("ch"+num2str(jSc_pickedChannel)+"image")
	
	Variable	frameNo = jSc_LS_sliceNo*jSc_LS_nChannels+jSc_pickedChannel-1			// jSc_pickedChannel is one-based, but jSc_LS_sliceNo is zero-based

	imageTransform/P=(frameNo) getplane imSource
	WAVE		M_ImagePlane
	Duplicate/O M_ImagePlane,jSc_2pZap_image

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pick stack channel to be loaded for selecting 2p zap positions

Function jSc_load2pZapStack()
	
	Make /O jSc_2pZapStack
	KillDataFolder/Z root:Tag0											// Avoid having these data folders build up as more images are loaded
	KillDataFolder/Z root:Tag1
	PathInfo/S Home
	ImageLoad/Q/Z/BIGT=1/LTMD/T=tiff/C=-1/O/N='jSc_2pZapStackRAW'
	if (V_flag==0)
		Print "No file was loaded."
		Abort
	endif
	Variable	nImagesLoaded = DimSize(jSc_2pZapStackRAW,2)
	String	ImageFileName = S_fileName
	print "Loaded "+num2str(nImagesLoaded)+" frames from the file \""+ImageFileName+"\" from path \""+S_path+"\"."
	WAVE/T	T_Tags = root:Tag0:T_Tags
	String/G jSc_RAT_Str = T_Tags[jSc_FindImageDescription(T_Tags)]
	KillDataFolder/Z root:Tag0											// Avoid having these data folders build up as more images are loaded
	KillDataFolder/Z root:Tag1											// This is in case of crash, so Tag folders build up, adding an extra Kill for safety's sake
	
	Print "\t\tThe image size is "+StringByKey("pxpl",jSc_RAT_Str,"=","\r")+" pixels by "+StringByKey("lnpf",jSc_RAT_Str,"=","\r")+" lines"
	//// REMINDER: Move these variables to GlobalVar init at beginning of code
	Variable/G	jSc_LS_nSlices				// Actual number of slices saved (stack could have been interrupted)
	Variable/G	jSc_LS_nChannels
	Variable/G	jSc_LS_stkStart				// Start of stack in µm
	Variable/G	jSc_LS_stkEnd				// End of stack in µm		(unless interrupted)
	Variable/G	jSc_LS_stkSliceSpacing		// Slice spacing in µm		(this parameter was not saved in an earlier version of SaveTIFF(1)
	if (NumberByKey("ETLstack",jSc_RAT_Str,"=","\r"))
		jSc_LS_nSlices = NumberByKey("sliceCounter",jSc_RAT_Str,"=","\r")
		jSc_LS_nChannels = NumberByKey("Ch1on",jSc_RAT_Str,"=","\r")+NumberByKey("Ch2on",jSc_RAT_Str,"=","\r")+NumberByKey("Ch3on",jSc_RAT_Str,"=","\r")
		print "\t\tThis is a "+num2str(jSc_LS_nChannels)+"-channel ETL stack consisting of "+num2str(jSc_LS_nSlices)+" slices."
		jSc_LS_stkStart = NumberByKey("stkStart",jSc_RAT_Str,"=","\r")
		jSc_LS_stkEnd = NumberByKey("stkEnd",jSc_RAT_Str,"=","\r")
		print "\t\tETL runs from "+num2str(jSc_LS_stkStart)+" µm to "+num2str(jSc_LS_stkEnd)+" µm."
		print "\t\tInfo about this stack is found in: jSc_RAT_Str"
	else
		print "\t\tThis is not an ETL stack. This only works with ETL stacks."
		Abort "This is not an ETL stack. This only works with ETL stacks."
	endif

// Key variables for handling the ETL stack
// ----------------------------------------
//	Variable		direction = 1
//	if (jSc_stkStart>jSc_stkEnd)
//		direction = -1
//	endif
//	NVAR		jSc_ETLcommand
//	NVAR		jSc_ETLmicron
//	jSc_ETLmicron = jSc_stkStart+jSc_sliceCounter*jSc_stkSliceSpacing*direction
//	jSc_ETLcommand = jSc_MicronToETL(jSc_ETLmicron)
//	jSc_updateETLcommand()

// Fake save: 	ImageSave/U/O/IGOR/D=16/S/T="tiff"/P=jScPath/WT=jSc_Tags jSc_2pZapStackRAW as "exp_01_0069.tif"

End

///////////////////////////////////////////////////////////////
//// Find ImageDescription tag
//// For reasons that are unclear to me, the JT_FindIMAGEDESCRIPTION does not work (Igor's old TIFF loader works differently?)

Function jSc_FindImageDescription(theWave)
	WAVE/T	theWave

	Variable	theIndex = -1
	
	Variable	i = 0
	Variable	nRows = DimSize(theWave,0)
	
	do
		if (strsearch(theWave[i],"ImageDescription",0)>-1)
			theIndex = i
			i = Inf
		endif
		i += 1
	while (i<nRows)

	Return	theIndex
	
end
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pick channel to be used for selecting 2p zap positions

Function jSc_draw2pZapImage(which)
	Variable		which
	
	Variable/G	jSc_2pZapRememberWhich = which				// REMINDER: Transition from using jSc_2pZapRememberWhich to using jSc_pickedChannel, for consistency's sake
	
	NVAR		jSc_pickedFromStack
	
	NVAR		LUTstart = $("jSc_LUTstart"+num2str(jSc_2pZapRememberWhich))
	NVAR		LUTend = $("jSc_LUTend"+num2str(jSc_2pZapRememberWhich))
	NVAR		jSc_pickThreshold 
	NVAR		jSc_minPixels
	NVAR		jSc_maxPixels

	jSc_pickThreshold = Round((LUTstart+LUTend)/2)

	NVAR		jSc_imSize
	NVAR		jSc_imCounter
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	
	WAVE		jSc_2pZap_image

	Variable	ScSc = PanelResolution("")/ScreenResolution

	Variable	xPos = 292+28
	Variable	yPos = 50
	Variable	Width = jSc_imSize*1.5
	Variable	nLines = 2				// Number of lines with controls in the controlBar
	if (jSc_pickedFromStack)
		nLines = 3
	endif
	Variable	controlBarHeight = 25*nLines
	Variable	Height = Width+controlBarHeight

	Variable	xSize = JT_ScreenSize(0)
	Variable	ySize = JT_ScreenSize(1)

	DoWindow /K jSc_2pZapImage
	Display/K=1 /W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width,yPos*ScSc+Height) as "Channel "+num2str(which)
	DoWindow /C jSc_2pZapImage
	DoWindow/T jSc_2pZapImage,"Pick points from channel "+num2str(which)

	// Add image
	AppendImage /T jSc_2pZap_image
//	AppendImage /T $("ch"+num2str(which)+"image")
	
	// Add picked data points
	AppendToGraph/T/L jSc_pointsY vs jSc_pointsX
	ModifyGraph mode(jSc_pointsY)=4
	ModifyGraph mrkThick(jSc_pointsY)=1
	ModifyGraph marker(jSc_pointsY)=8
	ModifyGraph RGB(jSc_pointsY)=(131*256,158*256,187*256)
	ModifyGraph mstandoff(jSc_pointsY)=1
	
	// Add numerical labels for picked data points
	AppendToGraph/T/L jSc_pointsY vs jSc_pointsX
	ModifyGraph mode(jSc_pointsY#1)=3,textMarker(jSc_pointsY#1)={jSc_pointsN,"default",0,0,0,2.00,2.00}
	ModifyGraph RGB(jSc_pointsY#1)=(131*256,158*256,187*256)	
	
	// Add voltage trace
	AppendToGraph/B/R jSc_yVw vs jSc_xVw
	ModifyGraph mode(jSc_yVw)=4
	ModifyGraph RGB(jSc_yVw)=(187*256,0*256,187*256)
	ModifyGraph mode(jSc_yVw)=2
	ModifyGraph height={Aspect,1}
	
	Cursor/P/I/H=1/C=(55*256,119*256,187*256) A jSc_2pZap_image Round(jSc_pxpl/2),Round(jSc_lnpf/2)
//	Cursor/P/I/H=1/C=(55*256,119*256,187*256) A $("ch"+num2str(which)+"image") Round(jSc_pxpl/2),Round(jSc_lnpf/2)
	ShowInfo

	Variable theMargin = 22
	ModifyGraph margin(left)=theMargin,margin(bottom)=theMargin,margin(top)=theMargin,margin(right)=theMargin
	ModifyGraph nticks=6
	ModifyGraph minor=1
	ModifyGraph fSize=9
	ModifyGraph standoff=0
	ModifyGraph tkLblRot(left)=90
	ModifyGraph tkLblRot(right)=90
	ModifyGraph btLen=3
	ModifyGraph tlOffset=-2
	SetAxis/A/R left								// Images start with the origin top left, so y-axis voltages have to be plotted upside down?
	SetAxis bottom,-jSc_xAmp,jSc_xAmp
	SetAxis right,jSc_yAmp,-jSc_yAmp
	Label left "\\Zr075\\u#2pixels"
	Label top "\\Zr075\\u#2pixels"
	Label right "\\Zr075\\u#2voltage"
	Label bottom "\\Zr075\\u#2voltage"
	
	ModifyGraph nticks(right)=3,nticks(bottom)=3

	AutoPositionWindow/E/M=0/R=j2pZapPanel jSc_2pZapImage

	Variable	xSkip = 36
	Variable	bSep = 2
	Variable	vSp = 2
	Variable	xx = bSep
	Variable	yy = 2
	Variable	h = 21
	Variable	fontSize=10
	ControlBar controlBarHeight
	Button AutoPickButton,pos={xx,yy},size={xSkip,h},proc=jSc_2pZapAutoPickProc,title="Auto",fsize=fontSize,font="Arial"
	xx += xSkip+bSep
 	Slider ThresholdSlider,pos={xx,yy+2},size={xSkip*3,h},ticks=0,side=0,vert=0,variable=jSc_pickThreshold,limits={LUTstart,LUTend,1},proc=TresholdSliderProc,fsize=fontSize,font="Arial"
	xx += xSkip*3+bSep
	SetVariable ShowThresholdSV,pos={xx,yy+3},size={xSkip*1.5,h},title=" ",variable=jSc_pickThreshold,limits={LUTstart,LUTend,0},fsize=fontSize,font="Arial"
	xx += xSkip*1.5+bSep
	SetVariable minPixelsSV,pos={xx,yy+3},size={xSkip*2,h},title="min",variable=jSc_minPixels,limits={0,200,1},fsize=fontSize,font="Arial"
	xx += xSkip*2+bSep
	SetVariable maxPixelsSV,pos={xx,yy+3},size={xSkip*2,h},title="max",variable=jSc_maxPixels,limits={100,Inf,100},fsize=fontSize,font="Arial"
	xx += xSkip*2+bSep
	// new line
	xx = bSep
	yy += h+vSp
	Button AddPointButton,pos={xx,yy},size={xSkip*0.8,h},proc=jSc_AddPointProc,title="Add",fsize=fontSize,font="Arial"
	xx += xSkip*0.8+bSep
	Button MovePointButton,pos={xx,yy},size={xSkip,h},proc=jSc_moveClosest2pZapHere,title="Move",fsize=fontSize,font="Arial"
	xx += xSkip+bSep
	Button DropPointButton,pos={xx,yy},size={xSkip,h},proc=jSc_dropClosest2pZapHere,title="Drop",fsize=fontSize,font="Arial"
	xx += xSkip+bSep
	Button DropLastPointButton,pos={xx,yy},size={xSkip*1.4,h},proc=jSc_DropLastPointProc,title="Drop last",fsize=fontSize,font="Arial"
	xx += xSkip*1.4+bSep
	Button ClearAllPointsButton,pos={xx,yy},size={xSkip*1.4,h},proc=jSc_ClearAllPointsProc,title="Clear all",fsize=fontSize,font="Arial"
	xx += xSkip*1.4+bSep
	Button EditAllPointsButton,pos={xx,yy},size={xSkip,h},proc=jSc_EditAllPointsProc,title="Edit",fsize=fontSize,font="Arial"
	xx += xSkip+bSep
	Button MakePathButton,pos={xx,yy},size={xSkip,h},proc=jSc_2pZapMakePathProc,title="Path",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	xx += xSkip+bSep
	CheckBox ShowCheck,pos={xx,yy+2},size={xSkip,h},proc=jSc_ShowVTraceCheckProc,title="Show path",fsize=fontSize,font="Arial",value=1
	xx += xSkip+bSep
	// new line
	if (jSc_pickedFromStack)
		xx = bSep
		yy += h+vSp
		NVAR		jSc_LS_nSlices
		SetVariable ShowSliceSV,pos={xx,yy+3},size={xSkip*2,h},title="Slice:",variable=jSc_LS_pickSlice,limits={0,jSc_LS_nSlices-1,1},proc=ShowSliceProc,fsize=fontSize,font="Arial"
		xx += xSkip*2+bSep
	 	Slider SliceSlider,pos={xx,yy},size={xSkip*3,h},ticks=-1,vert=0,variable=jSc_LS_pickSlice,limits={0,jSc_LS_nSlices-1,1},proc=SliceSliderProc,fsize=fontSize,font="Arial"
		xx += xSkip*3+bSep
	endif

	doUpdate
	jSc_updateLUT(which,targetIs2pZap=1)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Choose the slice from the recently loaded stack

Function ShowSliceProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	NVAR	jSc_pickedChannel
	NVAR	jSc_LS_sliceNo
	
	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			jSc_LS_sliceNo = sva.dval
			jSc_pickSliceFor2pZapImage()				// Pick slice from stack
			jSc_updateLUT(jSc_pickedChannel,targetIs2pZap=1,setThreshold=0)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function SliceSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa
	
	NVAR	jSc_pickedChannel
	NVAR	jSc_LS_sliceNo
	
	jSc_LS_sliceNo = sa.curval
	
	switch( sa.eventCode )
		case -1: // kill
			break
		default:
			if( sa.eventCode & 2^0 ) // value set -- set threshold
				jSc_pickSliceFor2pZapImage()				// Pick slice from stack
				jSc_updateLUT(jSc_pickedChannel,targetIs2pZap=1,setThreshold=0)
				// REMINDER: Remove path while sliding
			endif
			if( sa.eventCode & 2^2 ) // mouse up -- revert to LUT
				jSc_pickSliceFor2pZapImage()				// Pick slice from stack
				jSc_updateLUT(jSc_pickedChannel,targetIs2pZap=1,setThreshold=0)
				// REMINDER: Update path for this slice on mouse-up
			endif
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Choose the threshold from which cells are automatically picked

Function TresholdSliderProc(sa) : SliderControl
	STRUCT WMSliderAction &sa
	
	NVAR	jSc_2pZapRememberWhich
	NVAR	jSc_pickThreshold
	
	switch( sa.eventCode )
		case -1: // kill
			break
		default:
			if( sa.eventCode & 2^0 ) // value set -- set threshold
				ModifyGraph/W=jSc_2pZapImage hideTrace(jSc_yVw)=1,hideTrace(jSc_pointsY)=1,hideTrace(jSc_pointsY#1)=1
				jSc_pickThreshold = sa.curval
				jSc_updateLUT(jSc_2pZapRememberWhich,targetIs2pZap=1,setThreshold=1)
			endif
			if( sa.eventCode & 2^2 ) // mouse up -- revert to LUT
				ModifyGraph/W=jSc_2pZapImage hideTrace(jSc_pointsY)=0,hideTrace(jSc_pointsY#1)=0
				ControlInfo/W=jSc_2pZapImage ShowCheck
				if (V_Value)
					ModifyGraph/W=jSc_2pZapImage hideTrace(jSc_yVw)=0
				else
					ModifyGraph/W=jSc_2pZapImage hideTrace(jSc_yVw)=1
				endif
				jSc_updateLUT(jSc_2pZapRememberWhich,targetIs2pZap=1,setThreshold=0)
			endif
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Automatically pick cells by thresholding the image

Function jSc_2pZapAutoPickProc(ctrlName) : ButtonControl
	String	ctrlName
	
	NVAR		jSc_2pZapRememberWhich
	
	JSc_AutoPickPoints(jSc_2pZapRememberWhich)
		
End

Function JSc_AutoPickPoints(which)
	Variable	which

	WAVE		targetImage = jSc_2pZap_image
	NVAR		jSc_pickThreshold
	NVAR		jSc_minPixels
	NVAR		jSc_maxPixels

	ImageThreshold/I/M=0/T=(jSc_pickThreshold) targetImage
	WAVE/Z		M_ImageThresh

	ImageAnalyzeParticles/A=(jSc_minPixels)/MAXA=(jSc_maxPixels)/M=1/EBPC/E stats M_ImageThresh
	
	WAVE/Z		W_SpotX				// Bug in Igor: ImageAnalyzeParticles creates these waves, yet /Z has to be used or else we get debug error
	WAVE/Z		W_SpotY
	WAVE/Z		W_SpotN
	WAVE/Z		M_Moments
	
	Variable/G jSc_nPoints = numpnts(W_SpotX)
	
	Make/O/N=(jSc_nPoints) jSc_pointsX,jSc_pointsY,jSc_pointsN
	
	WAVE			jSc_pointsX
	WAVE			jSc_pointsY
	WAVE			jSc_pointsN

	if (jSc_nPoints>0)
		jSc_pointsX = M_Moments[p][0]
		jSc_pointsY = M_Moments[p][1]
		jSc_pointsN = p
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Toggle show/hide the voltage trace

Function jSc_ShowVTraceCheckProc(cba) : CheckBoxControl
	STRUCT WMCheckboxAction &cba

	switch( cba.eventCode )
		case 2: // mouse up
			Variable checked = cba.checked
			if (checked)
				ModifyGraph/W=jSc_2pZapImage hideTrace(jSc_yVw)=0
			else
				ModifyGraph/W=jSc_2pZapImage hideTrace(jSc_yVw)=1
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the 2p zap path

Function jSc_2pZapMakePathProc(ctrlName) : ButtonControl
	String ctrlName
	
	jSc_2pZapPath2voltages()
		
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Produce an Archimedean spiral with constant arc

Function jSc_makeArchimedeanSpiral()

	NVAR		jSc_stim_shutterTime
	NVAR		jSc_stim_sampFreq

	NVAR 		jSc_SpiralArc
	NVAR		jSc_SpiralSeparation
	
	Variable	xOffs = 0
	Variable	yOffs = 0

	Variable n = jSc_stim_shutterTime*1e-3*jSc_stim_sampFreq
	Make/O/N=(n) jSc_spiralX,jSc_spiralY
	jSc_spiralX = 0
	jSc_spiralY = 0

	Variable r = jSc_SpiralArc*1e-3
	Variable	b = jSc_SpiralSeparation*1e-3/(2*Pi)
	Variable	phi = r/b//+2*Pi*4	// Here, 4 is number of turns out from the origin that the spiral starts
	Variable i = 0
	do
		r = b * phi
		jSc_spiralX[i] = r*cos(phi+pi)+xOffs
		jSc_spiralY[i] = r*sin(phi+pi)+yOffs
		phi = phi + (jSc_SpiralArc*1e-3/r)
		i += 1
	while (i<n)
//	print "Archimedean spiral endpoint radius:",r*1e3,"mV"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Calibrate spiral scan spiral separation value with shutter opening time

Function jSc_calibrateSpiral()

	NVAR		jSc_stim_shutterTime
	NVAR		jSc_SpiralSeparation

	WAVE		jSc_spiralX,jSc_spiralY

	Variable nPoints
	Variable lx
	Variable ly
	
	print "For the arbitrary spiral scan radius of 80 mV, the spiral separation should be scaled with shutter time as follows:"

	Make/O shutterTimeW = {3,4,5,6,7,8,9,10,11,12,13,14,15}
	Duplicate/O shutterTimeW,SpiralSeparationW,SpiralPowerW

	Variable	n = numpnts(shutterTimeW)
	Variable	SpiralSeparationVal
	Variable	step = 0.1
	Variable	i
	i = 0
	do
		jSc_stim_shutterTime = shutterTimeW[i]
		jSc_SpiralSeparation = 40
		do
			jSc_SpiralSeparation -= step
			jSc_makeArchimedeanSpiral()
			nPoints = numpnts(jSc_spiralY)
			lx = jSc_spiralX[nPoints-1]
			ly = jSc_spiralY[nPoints-1]
		while(sqrt(lx^2+ly^2)>0.080)				// 0.080 is an arbitrary reference point
		SpiralSeparationW[i] = jSc_SpiralSeparation
		print "\t\t"+JT_num2digstr(2,jSc_stim_shutterTime)+" ms shutter time gives spiral separation "+num2str(jSc_SpiralSeparation)+" mV."
		i += 1
	while(i<n)
	
	SpiralPowerW = 100*1/5*shutterTimeW

	jSc_stim_shutterTime = 5
	jSc_SpiralSeparation = 20

	doWindow/K spiralScanCalib1
	Display/K=1 /W=(169,188,501,380) SpiralSeparationW vs shutterTimeW as "Spiral scan calibration 1"
	doWindow/C spiralScanCalib1
	ModifyGraph rgb=(60416,7168,9216)
	ModifyGraph grid=1
	ModifyGraph fSize=12
	ModifyGraph gridHair=1
	Label left "Spiral separation (mV)"
	Label bottom "shutter time (ms)"
	Legend/C/N=text0/J "\\Z10How to scale spiral separation\rwith shutter time"
	JT_addCloseButton()

	doWindow/K spiralScanCalib2
	Display/K=1 /W=(512,186,844,378) SpiralPowerW vs shutterTimeW as "Spiral scan calibration 2"
	doWindow/C spiralScanCalib2
	ModifyGraph rgb=(60416,7168,9216)
	ModifyGraph grid=1
	ModifyGraph fSize=12
	ModifyGraph gridHair=1
	ModifyGraph manTick(left)={0,50,0,0},manMinor(left)={4,0}
	Label left "normalized power (%)"
	Label bottom "shutter time (ms)"
	Legend/C/N=text0/J/A=LT "\\Z10How power scales\rwith shutter time"
	JT_addCloseButton()

	doWindow/K spiralScanCalib3
	Edit/K=1/W=(280,422,723,634) shutterTimeW,SpiralSeparationW,SpiralPowerW as "Spiral Scan Table"
	doWindow/C spiralScanCalib3
	ModifyTable format(Point)=1,width(shutterTimeW)=100,title(shutterTimeW)="Shutter time (ms)"
	ModifyTable width(SpiralSeparationW)=124,title(SpiralSeparationW)="Spiral separation (mV)"
	ModifyTable width(SpiralPowerW)=132,title(SpiralPowerW)="Norm spiral power (%)"
	
	JT_ArrangeGraphs2("spiralScanCalib1;spiralScanCalib2;spiralScanCalib3;",4,4)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot the Archimedean spiral

Function jSc_plotArchimedeanSpiral()

	if (Exists("jSc_spiralY"))

		DoWindow/K ArchiSpiralGraph
		Display /W=(35,45,435,439) jSc_spiralY vs jSc_spiralX as "Archimedean Spiral"
		DoWindow/C ArchiSpiralGraph
		ModifyGraph mode=4
		JT_addCloseButton()

	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Convert the 2p zap path to voltage values

Function jSc_2pZapPath2voltages()

	WAVE			jSc_pointsX
	WAVE			jSc_pointsY
	
	Variable/G	jSc_nPoints = numpnts(jSc_pointsX)
	
	if (jSc_nPoints==0)
		print "You have to pick some points first!"
		Abort "You have to pick some points first!"
	endif
	
	// Convert the uncaging pattern to voltage values
	NVAR		jSc_mspl
	NVAR		jSc_flyback
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	NVAR		jSc_xPad
	
	NVAR		jSc_ZoomFactor
	
	NVAR		xSpots = jSc_pxpl
	NVAR		ySpots = jSc_lnpf	

	NVAR		jSc_stim_sampFreq
	NVAR		jSc_unc_flyTime
	NVAR		jSc_stim_dwellTime
	NVAR		jSc_stim_shutterTime
	NVAR		jSc_stim_nPulses
	NVAR		jSc_stim_PulsePrePad
	NVAR		jSc_stim_freq
	
	NVAR		jSc_stim_shutterOpen
	NVAR		jSc_stim_shutterClosed
	
	NVAR		jSc_GatePadStart
	NVAR		jSc_GatePadEnd
	
	NVAR		jSc_deltaT1
	NVAR		jSc_deltaT2
	
	SVAR		jSc_noSpikeList
	SVAR		jSc_addOffsetList

	if ( (itemsinlist(jSc_noSpikeList)!=jSc_nPoints) %| (itemsinlist(jSc_addOffsetList)!=jSc_nPoints) )
		jSc_makeSpikeListsMatchNpoints()
	endif

	NVAR		jSc_spikeOffset
	Variable	currSpikeOffset = 0
	
	NVAR		jSc_VerboseMode

	Variable	dwellPoints = jSc_stim_dwellTime*1e-3*jSc_stim_sampFreq						// Number of sample points for each dwell time
	Variable	flyPoints = jSc_unc_flyTime*1e-3*jSc_stim_sampFreq							// Number of sample points for each fly time
	Variable	totDwellPoints = dwellPoints+flyPoints										// Total number of sample points for each uncaging location
	Variable	nSamplePoints = totDwellPoints*jSC_nPoints									// Total number of sample points for entire sweep
	Variable	wDur = nSamplePoints/jSc_stim_sampFreq										// Uncaging sweep duration from points (s)
	Variable	calc_wDur = (jSc_stim_dwellTime+jSc_unc_flyTime)*1e-3*jSC_nPoints			// Uncaging sweep duration from time (s)
	Variable	prePadPoints = jSc_stim_PulsePrePad*1e-3*jSc_stim_sampFreq
	Variable	stimPoints = jSc_stim_shutterTime*1e-3*jSc_stim_sampFreq 					// Shutter opening time, raw (see adjusted below)
	Variable	stimPointsAdj = (jSc_stim_shutterTime+jSc_GatePadStart-jSc_GatePadEnd)*1e-3*jSc_stim_sampFreq // Shutter opening time accounting for delay to open and delay to close
	Variable stimShiftPoints = jSc_GatePadStart*1e-3*jSc_stim_sampFreq						// Shutter opening has to happen this many samples earlier to account for opening delay
	Variable	freqInPoints = Round(jSc_stim_sampFreq/jSc_stim_freq)
//	Variable	nSamplePoints = wDur*jSc_stim_sampFreq										// Total number of sample points for entire sweep

	if (jSc_VerboseMode)
		print "Actual uncaging sweep duration:",wDur,"s"
		print "Calculated sweep duration:",calc_wDur,"s (any mismatch is due to rounding errors)"
		print "The uncaging sweep runs at "+num2str(jSc_stim_sampFreq/1e3)+" kHz sampling frequency."
		print "Total number of sample points in uncaging sweep:",nSamplePoints
		print "\tNumber of sample points for each uncaging location:",totDwellPoints
		print "\t\tNumber of sample points spent dwelling:",dwellPoints
		print "\t\tNumber of sample points spent flying:",flyPoints
		print "\t\tNumber of prepad points before uncaging:",prePadPoints
		print "\t\tNumber of points per uncaing pulse:",stimPoints
		print "\t\tNumber of pulses:",jSc_stim_nPulses
		print "\t\tShutter opening delay:",jSc_GatePadStart,"ms"
		print "\t\tShutter closing delay:",jSc_GatePadEnd,"ms"
		if (jSc_stim_nPulses>1)
			print "\t\tUncaging pulse starting points in a train are separated by this many points:",freqInPoints
		else
			print "\t\tThere is only one uncaging pulse, so uncaging pulse frequency does not apply."
		endif
	endif
	Make/O/N=(nSamplePoints) jSc_xVw,jSc_yVw,jSc_shutterWave,jSc_blankWave
	jSc_xVw = 0
	jSc_yVw = 0
	jSc_shutterWave = jSc_stim_shutterClosed
	jSc_blankWave = 0
	Variable	kx,ky,mx,my
	Variable	xV,yV
	NVAR	jSc_max_xAmp
	NVAR	jSc_max_yAmp
	Variable	xV_old = jSc_max_xAmp		// Assuming the laser beam first starts out at these park values (was 0 before)
	Variable	yV_old = jSc_max_yAmp		// Assuming the laser beam first starts out at these park values (was 0 before)
	Variable	i,j
	
	//// Create the template for the Archimedean spirals
	jSc_makeArchimedeanSpiral()
	WAVE	jSc_spiralX
	WAVE	jSc_spiralY

	//// Set up to create postsynaptic current injection waves
	NVAR	SampleFreq =			root:MP:SampleFreq				// Sampling frequency [Hz]
	NVAR	SealTestPad1 = 		root:MP:SealTestPad1				// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	if (!(Exists("SpTm_wDur")))
		SpTm2WavesSetup()											// Set up the SpTm2Waves procedure if not already done
	endif
	Make/O/N=(0) SpikeTimes_1										// Erase old spike times
	Make/O/N=(0) SpikeTimes_2
	Make/O/N=(0) SpikeTimes_3
	Make/O/N=(0) SpikeTimes_4
	Variable tStep = -(jSc_deltaT1-jSc_deltaT2)/(jSc_nPoints-1)		// Reversed sign convention for dT, 30 Aug 2018, JSj

	//// Create x and y command voltages as well as the shutter control
	i = 0
	do
		// Fly to new point
		xV = (jSc_pointsX[i]-xSpots/2+0.5) * 2/(xSpots-1) * jSc_xAmp * (xSpots-1)/xSpots / jSc_ZoomFactor
		yV = (jSc_pointsY[i]-ySpots/2+0.5) * 2/(ySpots-1) * jSc_yAmp * (ySpots-1)/ySpots / jSc_ZoomFactor
		kx = (xV-xV_old)/(flyPoints+1)
		ky = (yV-yV_old)/(flyPoints+1)
		mx = xV_old
		my = yV_old
		jSc_xVw[i*totDwellPoints,i*totDwellPoints+flyPoints-1] = kx*(p-i*totDwellPoints+1)+mx
		jSc_yVw[i*totDwellPoints,i*totDwellPoints+flyPoints-1] = ky*(p-i*totDwellPoints+1)+my
		// Dwell at point
		jSc_xVw[i*totDwellPoints+flyPoints,i*totDwellPoints+totDwellPoints-1] = xV
		jSc_yVw[i*totDwellPoints+flyPoints,i*totDwellPoints+totDwellPoints-1] = yV
		
		// Add uncaging pulses
		j = 0
		do
			jSc_shutterWave[i*totDwellPoints+prePadPoints+freqInPoints*j-stimShiftPoints,i*totDwellPoints+prePadPoints+freqInPoints*j-stimShiftPoints+stimPointsAdj-1] = jSc_stim_shutterOpen
			// Add Archimedean spirals with constant arc at uncaging points
			jSc_xVw[i*totDwellPoints+prePadPoints+freqInPoints*j,i*totDwellPoints+prePadPoints+freqInPoints*j+stimPoints-1] += jSc_spiralX[p-(i*totDwellPoints+prePadPoints+freqInPoints*j)]
			jSc_yVw[i*totDwellPoints+prePadPoints+freqInPoints*j,i*totDwellPoints+prePadPoints+freqInPoints*j+stimPoints-1] += jSc_spiralY[p-(i*totDwellPoints+prePadPoints+freqInPoints*j)]
			j += 1
		while(j<jSc_stim_nPulses)
		// Remember timing of postsynaptic current injection
		if (str2num(stringfromlist(i,jSc_noSpikeList))==0)		// ... but only if user wants a spike at this location
			currSpikeOffset = jSc_spikeOffset*str2num(stringfromlist(i,jSc_addOffsetList))	// Add spike offset
			SpikeTimes_1[numpnts(SpikeTimes_1)] = {(i*totDwellPoints+prePadPoints)/jSc_stim_sampFreq+(tStep*i+jSc_deltaT1+currSpikeOffset)*1e-3}		// Reversed sign convention for dT, 30 Aug 2018, JSj
		endif
		// Remember this point for next flight
		xV_old = xV
		yV_old = yV
		i += 1
	while(i<jSc_nPoints)
	Duplicate/O SpikeTimes_1,SpikeTimes_2,SpikeTimes_3,SpikeTimes_4
	
	// If not doing plasticity experiments, just connectivity mapping, while recording more than one cell, the last spikes should be staggered to avoid monosynaptic responses from colliding
	NVAR	jSc_staggerLastSpikeAcrossChannels
	if (jSc_staggerLastSpikeAcrossChannels>0)
		Variable	lastSpikeTime
		// Ch2
		lastSpikeTime = SpikeTimes_2[numpnts(SpikeTimes_2)-1]
		SpikeTimes_2[numpnts(SpikeTimes_2)-1] = lastSpikeTime+jSc_staggerLastSpikeAcrossChannels*1e-3*1
		// Ch3
		lastSpikeTime = SpikeTimes_3[numpnts(SpikeTimes_3)-1]
		SpikeTimes_3[numpnts(SpikeTimes_3)-1] = lastSpikeTime+jSc_staggerLastSpikeAcrossChannels*1e-3*2
		// Ch4
		lastSpikeTime = SpikeTimes_4[numpnts(SpikeTimes_4)-1]
		SpikeTimes_4[numpnts(SpikeTimes_4)-1] = lastSpikeTime+jSc_staggerLastSpikeAcrossChannels*1e-3*3
	endif

	SetScale/P x 0,1/jSc_stim_sampFreq,"s", jSc_xVw,jSc_yVw,jSc_shutterWave,jSc_blankWave
	SetScale d 0,0,"V", jSc_xVw,jSc_yVw,jSc_shutterWave,jSc_blankWave

	//// Create postsynaptic current injection waves
	NVAR/Z		SpTm_wDur
	Variable testPulseDur = SealTestDur+SealTestPad1+SealTestPad2
	SpTm_wDur = Rightx(jSc_shutterWave)+testPulseDur*1e-3			// Accounting for test pulse duration
	NVAR	jSc_padAfterLastSpike
	SpTm_wDur += jSc_padAfterLastSpike*1e-3							// Pad after last spike
	RunSpTm2Waves()													// This creates Out_1_ST through Out_4_ST
	WAVE		Out_1_ST,Out_2_ST,Out_3_ST,Out_4_ST
	Duplicate/O Out_1_ST,Out_1										// Then create Out_1 through Out_4
	Duplicate/O Out_2_ST,Out_2
	Duplicate/O Out_3_ST,Out_3
	Duplicate/O Out_4_ST,Out_4
	Out_1[0,numpnts(jSc_xVw)-1] = 0									// Delete all spike-generating current injections, but keep the test pulse at the end
	Out_2[0,numpnts(jSc_xVw)-1] = 0
	Out_3[0,numpnts(jSc_xVw)-1] = 0
	Out_4[0,numpnts(jSc_xVw)-1] = 0
	if (jSc_VerboseMode)
		print "Automatically generated ePhys waves called:\tOut_1_ST to Out_4_ST, as well as Out_1 to Out_4."
	endif

	//// Modify shutter wave
	Duplicate/O jSc_shutterWave,jSc_GateWave									// Use GateWave when sending from imaging board, use ShutterWave when sending from ePhys board
	jSc_GateWave[numpnts(jSc_GateWave)-1] = jSc_stim_shutterClosed				// Make sure last data point indicates shutter closed
	Variable nMissingPoints = numpnts(Out_1_ST)-numpnts(jSc_shutterWave)		// Because of test pulse, the e-phys waves are longer than the shutter wave
	if (nMissingPoints<0)
		print "Warning! Is the sample rate set differently for MultiPatch and for jScan? (check WaveCreator panel at top) Please set to the same value."	
		doAlert 0,"Warning! Is the sample rate set differently for MultiPatch and for jScan? (check WaveCreator panel at top) Please set to the same value."	
	endif
	if (jSc_VerboseMode)
		print "Number of missing points to be inserted at end of shutterWave:",nMissingPoints
	endif
	InsertPoints numpnts(jSc_shutterWave), nMissingPoints, jSc_shutterWave,jSc_blankWave	// Make sure they're the same length, otherwise e-phys data acquistion will choke
	jSc_shutterWave[numpnts(jSc_shutterWave)-nMissingPoints,numpnts(jSc_shutterWave)-1] = jSc_stim_shutterClosed		// Make sure added points indicate shutter closed
	jSc_blankWave[numpnts(jSc_blankWave)-nMissingPoints,numpnts(jSc_blankWave)-1] = jSc_stim_shutterClosed
	Duplicate/O jSc_shutterWave, Out_shutterWave												// Change wave name to start with Out_ to enable selection in panels that otherwise filter
	Duplicate/O jSc_blankWave, Out_blankWave												// these waves out from popup menus
	if (jSc_VerboseMode)
		print "Automatically generated shutter waves called:\tjSc_shutterWave, jSc_blankWave"
		print "\tCopied the above waves to:\tOut_shutterWave, Out_blankWave\tto be sent from ephys board"
		print "Also generated jSc_GateWave, to be sent from imaging board."
	endif
	
	//// Update rotation in case scan angle was changed
	NVAR	jSc_scanAngle
	jSc_Rotate(jSc_scanAngle,jSc_xVw,jSc_yVw)												// Is this really meaningful for 2p Zap procedures?
	
End

	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pick a 2p zap point

Function jSc_AddPointProc(ctrlName) : ButtonControl
	String ctrlName
	
	WAVE		jSc_pointsX
	WAVE		jSc_pointsY
	WAVE		jSc_pointsN
	
	String	CsrAStr = CsrInfo(A,"jSc_2pZapImage")

	Variable xPos = NumberByKey("POINT",CsrAStr)
	Variable yPos = NumberByKey("YPOINT",CsrAStr)
	
	if ( (xPos==jSc_pointsX[numpnts(jSc_pointsX)-1]) %& (yPos==jSc_pointsY[numpnts(jSc_pointsY)-1]) )
		doAlert/T="Are you insane?" 1,"Do you really want to add exactly the same coordinate AGAIN?"
		if (V_flag==2)
			print "Duplicate point was not added."
			Abort
		endif
	endif
	
	print "Adding coordinate (",xPos,",",yPos,") at",Time()
	
	jSc_pointsX[numpnts(jSc_pointsX)] = {xPos}
	jSc_pointsY[numpnts(jSc_pointsY)] = {yPos}
	
	Duplicate/O jSc_pointsY,jSc_pointsN
	jSc_pointsN = p
	
	print "\tThe number of points is now "+num2str(numpnts(jSc_pointsN))+"."

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Drop most recent 2p zap point

Function jSc_DropLastPointProc(ctrlName) : ButtonControl
	String	ctrlName
	
	WAVE		jSc_pointsX
	WAVE		jSc_pointsY
	WAVE		jSc_pointsN
	
	Variable/G	jSc_nPoints = numpnts(jSc_pointsX)
	
	if (jSc_nPoints>0)
		print "Deleting most recent 2p zap point (",jSc_pointsX[numpnts(jSc_pointsX)-1],",",jSc_pointsY[numpnts(jSc_pointsY)-1],") at ",Time()
		DeletePoints numpnts(jSc_pointsX)-1,1,jSc_pointsX,jSc_pointsY,jSc_pointsN
		print "\tThe number of points is now "+num2str(numpnts(jSc_pointsN))+"."
	else
		print "No points to delete, storage empty."
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move closest 2p zap point

Function jSc_moveClosest2pZapHere(ctrlName) : ButtonControl
	String	ctrlName

	WAVE		jSc_pointsX
	WAVE		jSc_pointsY
	WAVE		jSc_pointsN

	String	CsrAStr = CsrInfo(A,"jSc_2pZapImage")
	Variable xPos = NumberByKey("POINT",CsrAStr)
	Variable yPos = NumberByKey("YPOINT",CsrAStr)
	
	Duplicate/O jSc_pointsN,jSc_pointsDistance,jSc_pointsIndex
	
	Variable	n = numpnts(jSc_pointsN)
	
	if (n==0)
		print "You have no points to move!"
		Abort "You have no points to move!"
	endif
	Variable	i
	i = 0
	do
		jSc_pointsDistance[i] = sqrt( (xPos-jSc_pointsX[i])^2+(yPos-jSc_pointsY[i])^2 )
		i += 1
	while(i<n)
	
	Sort jSc_pointsDistance,jSc_pointsIndex
	
	Variable	closestIndex = jSc_pointsIndex[0]
	
	print "Do you want to move point "+num2str(closestIndex)+" here?"
	doAlert/T="Are you sure?" 1,"Do you want to move point "+num2str(closestIndex)+" here?"
	if (V_flag==1)
		print "Moving point "+num2str(closestIndex)+"."
		jSc_pointsX[closestIndex] = xPos
		jSc_pointsY[closestIndex] = yPos
	else
		print "Point "+num2str(closestIndex)+" was not moved."
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Drop closest 2p zap point

Function jSc_dropClosest2pZapHere(ctrlName) : ButtonControl
	String	ctrlName

	WAVE		jSc_pointsX
	WAVE		jSc_pointsY
	WAVE		jSc_pointsN

	String	CsrAStr = CsrInfo(A,"jSc_2pZapImage")
	Variable xPos = NumberByKey("POINT",CsrAStr)
	Variable yPos = NumberByKey("YPOINT",CsrAStr)
	
	Duplicate/O jSc_pointsN,jSc_pointsDistance,jSc_pointsIndex
	
	Variable	n = numpnts(jSc_pointsN)
	
	if (n==0)
		print "You have no points to drop!"
		Abort "You have no points to drop!"
	endif
	Variable	i
	i = 0
	do
		jSc_pointsDistance[i] = sqrt( (xPos-jSc_pointsX[i])^2+(yPos-jSc_pointsY[i])^2 )
		i += 1
	while(i<n)
	
	Sort jSc_pointsDistance,jSc_pointsIndex
	
	Variable	closestIndex = jSc_pointsIndex[0]
	
	print "Do you want to drop point "+num2str(closestIndex)+"?"
	doAlert/T="Are you sure?" 1,"Do you want to drop point "+num2str(closestIndex)+"?"
	if (V_flag==1)
		print "Dropping point "+num2str(closestIndex)+"."
		DeletePoints closestIndex,1,jSc_pointsX,jSc_pointsY,jSc_pointsN
		jSc_pointsN = p		// Remember to renumber points!
		print "\tThe number of points is now "+num2str(numpnts(jSc_pointsN))+"."
	else
		print "Point "+num2str(closestIndex)+" was not dropped."
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Clear all 2p zap points

Function jSc_ClearAllPointsProc(ctrlName) : ButtonControl
	String ctrlName
	
	WAVE		jSc_pointsX
	WAVE		jSc_pointsY
	WAVE		jSc_pointsN
	
	doAlert/T="Fo shizzle?" 1,"Do you really want to delete all stored points?"
	if (V_flag == 1)
		print "Deleting all 2p zap points at ",Time()
		Make/O/N=(0) jSc_pointsX,jSc_pointsY,jSc_pointsN
	else
		print "No 2p zap points were deleted."
	endif
	
End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Edit all 2p zap points

Function jSc_EditAllPointsProc(ctrlName) : ButtonControl
	String ctrlName
	
	WAVE		jSc_pointsX
	WAVE		jSc_pointsY
	
	DoWindow jSc_2pZapPointsTable
	if (V_flag)
		doWindow/F jSc_2pZapPointsTable
	else
		Edit/K=1/W=(5,45,273,328) jSc_pointsX,jSc_pointsY
		DoWindow/C jSc_2pZapPointsTable
		DoWindow/T jSc_2pZapPointsTable,"2p zap points"
		AutoPositionWindow/E/M=0/R=jSc_2pZapImage jSc_2pZapPointsTable
	endif
	
End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Change LUT

Function jSc_changeLUTProc(ctrlName,popNum,popStr) : PopupMenuControl
	String	ctrlName
	Variable	popNum
	String	popStr
	
	Variable	channel = str2num(ctrlName[6,6])
	NVAR	storedPopVal = $("jSc_LUTno"+num2str(channel))
	storedPopVal = popNum
	print "LUT on channel "+num2str(channel)+" was changed to "+popStr+"."
	
	jSc_updateLUT(channel)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Update LUT for specified image

Function jSc_updateLUT(channel, [targetIs2pZap, setThreshold])
	variable channel
	variable targetIs2pZap
	variable	setThreshold
	
	targetIs2pZap = ParamIsDefault(targetIs2pZap) ? 0 : targetIs2pZap
	setThreshold = ParamIsDefault(setThreshold) ? 0 : setThreshold
	
	WAVE/Z	jSc_2pZap_image

	NVAR	LUTstart = $("jSc_LUTstart"+num2str(channel))
	NVAR	LUTend = $("jSc_LUTend"+num2str(channel))
	NVAR	autoLUT = $("jSc_LUTauto"+num2str(channel))
	
	Variable	perc = 99		// Normalize histogram based on this percentage of pixel values; exclude the remainder as presumed outliers
	Variable	range,centre

	if (autoLUT)
		if (targetIs2pZap)
			imageStats jSc_2pZap_image
		else
			imageStats $("ch"+num2str(channel)+"image")
		endif
		range = (V_max-V_min)*perc/100
		centre = (V_max+V_min)/2
		LUTstart = Round(centre-range/2)
		LUTend = Round(centre+range/2)
	endif

	Controlinfo/W=$("jSC_ImageViewer"+num2str(channel)) $("LUTpop"+num2str(channel))		// Figure out LUT from popup menu
	if (targetIs2pZap)
		if (setThreshold)
			NVAR	jSc_pickThreshold
			ModifyImage/W=jSc_2pZapImage jSc_2pZap_image ctab= {jSc_pickThreshold,jSc_pickThreshold,$(S_Value),0}
		else
			ModifyImage/W=jSc_2pZapImage jSc_2pZap_image ctab= {LUTstart,LUTend,$(S_Value),0}
		endif
	else
		ModifyImage/W=$("jSC_ImageViewer"+num2str(channel)) $("ch"+num2str(channel)+"image") ctab= {LUTstart,LUTend,$(S_Value),0}
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Reset the stage XYZ coordinates to zero

Function jSc_stgZeroProc(ctrlName) : ButtonControl
	String ctrlName
	
	doAlert/T="Sanity check" 1,"Are you sure you want to reset the XYZ coordinates to zero?"
	if (V_flag==1)
		print "Resetting the XYZ coordinates to zero at time "+time()+"."
		jSc_COM_zero()
	endif

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Update stage XYZ coordinates

Function jSc_stgUpdateProc(ctrlName) : ButtonControl
	String ctrlName
	
	jSc_COM_getPos()

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Manage windows

Function jSc_manageImagesProc(ctrlName) : ButtonControl
	String ctrlName
	
	Variable	choice = str2num(ctrlName[2,2])
	switch(choice)
		case 1:
			jSc_im2front()
			break
		case 2:
			jSc_im2back()
			break
		case 3:
			jSc_killimages()
			break
	endswitch
	
End

Function jSc_im2front()

	DoWindow/F jSC_ImageViewer1
	DoWindow/F jSC_ImageViewer2
	DoWindow/F jSC_ImageViewer3

end

Function jSc_im2back()

	DoWindow/B jSC_ImageViewer1
	DoWindow/B jSC_ImageViewer2
	DoWindow/B jSC_ImageViewer3

end

Function jSc_killimages()

	DoWindow/K jSC_ImageViewer1
	DoWindow/K jSC_ImageViewer2
	DoWindow/K jSC_ImageViewer3

end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Acquire stack button

Function jSc_grabStackProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR		jSc_LoopFlag

	switch( ba.eventCode )
		case 2: // mouse up
			if (jSc_LoopFlag)
				print "Cannot acquire a stack while a loop is running!"
				print "To override in case of error state, execute this first:\rjSc_LoopFlag=0"
				break
			endif
			jSc_doGrabStack()
			break
	endswitch

	return 0
End

Function jSc_doGrabStack()

	NVAR		jSc_GrabStackFlag
	NVAR		jSc_ScanFlag
	NVAR		jSc_frameCounter
	NVAR		jSc_sliceCounter

	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ

	NVAR		jSc_nSlices
	
	NVAR		jSc_ETLexists
	
	NVAR		jSc_burstFrames

	Print "--- Acquire stack ---"

	PathInfo jScPath
	if (V_flag)
		if (jSc_GrabStackFlag)									// Stopping grabbing a stack
			Print "Interrupting stack acquistion at ",time()
			jSc_recoverAfterScan()								// Do not wait until frame is done -- stop right away, mid-scan!
			jSc_saveTIFF(1)										// Save partially acquired stack
			jSc_Stack_backToStart()
		else														// Starting a scan
			if (jSc_nSlices<2)
				print "A stack has to have at least two slices."
				abort "A stack has to have at least two slices."
			endif
			if (jSc_burstFrames)
				print "Sorry, you can presently not acquire stacks in burst-frames mode."
				abort "Sorry, you can presently not acquire stacks in burst-frames mode."
			endif
			Print "Starting stack acquistion at ",time()
			jSc_Stack_backToStart()
			jSc_GrabStackFlag = 1
			jSc_ScanFlag = 1
			jSc_frameCounter = 0
			jSc_sliceCounter = 0
			Button/Z grabStackButton,title="Stop",fColor=(65535,0,0),win=jStackPanel
			if (jSc_ETLexists)									// Disable ETL stack selection during stack acquisition so that user does not change mode mid-acquisition
				CheckBox/Z ETLstackCheck,disable=2,win=jStackPanel
			endif
			jSc_initGrabStackStorage()
			jSc_remakeScanIOdata()
			jSc_openShutter()
			jSc_setupAO()
			jSc_setupAIstack()
		endif
	else
		Beep
		print "You have to choose a save path first!"
		Abort "You have to choose a save path first!"
	endif


end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Calculate the corrected mspl
//// When NIDAQ carries out the scan, it rounds off the desired sample
//// frequency to the nearest possible sample frequency. This means
//// that the actual mspl can only be known after the scan has been 
//// initiated.

Function jSc_calcCorrectedmspl()

	WAVE		jSc_Ch1raw
	WAVE		jSc_xRaster
	NVAR		jSc_totmspl
	NVAR		jSc_corrtotmspl
	NVAR		jSc_actualSampFreq
	NVAR		jSc_actualFPS
	SVAR		jSc_reportStr
	NVAR		jSc_pixelBin
	NVAR		jSc_lnpf
	
	NVAR		jSc_burstFrames
	NVAR		jSc_nBurstFrames

	NVAR		jSc_Ch1on
	NVAR		jSc_Ch2on
	NVAR		jSc_Ch3on

	// The NIDAQ library will alter the wave scaling of any used wave to account for limited resolution
	// of built-in oscillators, so pick sample frequency from a used input wave.	
	if (jSc_Ch1on)
		WAVE	w = jSc_Ch1raw
	else
		if (jSc_Ch2on)
			WAVE	w = jSc_Ch2raw
		else
			if (jSc_Ch3on)
				WAVE	w = jSc_Ch2raw
			endif
		endif
	endif
	
	jSc_actualsampfreq = 1/dimdelta(w,0)

	Variable	calcSampFreq = 1/dimdelta(jSc_xRaster,0)/jSc_pixelBin

	jSc_corrtotmspl = jSc_totmspl*jSc_actualsampfreq/calcSampFreq
	
	Variable	lastSampleX = pnt2x(w,numpnts(w)-1)
	if (jSc_burstFrames)
		lastSampleX /= jSc_nBurstFrames
	endif
	jSc_actualFPS = 1/lastSampleX
	
	jSc_reportStr = ""
	jSc_reportStr += "\\f03Sample:\\f00 "+num2str(jSc_actualSampFreq*1e-3)+" kHz    "
	jSc_reportStr += "\\f03Line:\\f00 "+num2str(jSc_corrtotmspl)+" ms/line    "
	jSc_reportStr += "\\f03Frame:\\f00 "+num2str(jSc_actualFPS)+" Hz"

	Return jSc_corrtotmspl

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Run pseudorandom uncaging pattern

Function jSc_stimRunProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			NVAR		jSc_stim2pZapFlag
			if (stringMatch(ba.ctrlName,"ZapRunButton"))
				jSc_stim2pZapFlag = 1		// Determine which panel called this stim run
			else
				jSc_stim2pZapFlag = 0
			endif
			jSc_doStimRunProc()
			break
	endswitch

	return 0
End

Function jSc_doStimRunProc()

	Print "--- Running the uncaging pattern ---"

	NVAR		jSc_stimFlag
	NVAR		jSc_ProgPeriod
	NVAR		jSc_ProgVar
	NVAR		jSc_stimRunCounter
	
	WAVE		jSc_xVw
	WAVE		jSc_yVw
	
	if (Exists("jSc_yVw")==0)
		print "You must create the stimulation path first!"
		Abort "You must create the stimulation path first!"
	endif
	
	PathInfo jScPath
	if (V_flag)
		if (jSc_stimFlag)
			jSc_endStimRun()
		else
			jSc_stimFlag = 1
			jSc_stimRunCounter = 0
			Button/Z zapRunButton,title="Stop",fColor=(65535,0,0),win=j2pZapPanel
			Button/Z uncRunButton,title="Stop",fColor=(65535,0,0),win=jUncagePanel
			jSc_MakeProgressBar(0,"Stimulation progress")
			jSc_stim_newRun()
		endif
	else
		Beep
		print "You have to choose a save path first!"
		Abort "You have to choose a save path first!"
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Run grab loop

Function jSc_loopRunProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			jSc_doLoopRunProc()
			break
	endswitch

	return 0
End

Function jSc_doLoopRunProc()

	Print "--- Running grab loop ---"

	NVAR		jSc_LoopFlag
	NVAR		jSc_loopCounter
	
	PathInfo jScPath
	if (V_flag)
		if (jSc_LoopFlag)
			jSc_endLoopRun()
		else
			jSc_LoopFlag = 1
			jSc_loopCounter = 0
			Button/Z LoopButton,title="Stop loop",fColor=(65535,0,0),win=jScanPanel
			Button/Z GrabButton,title="Grab",fColor=(65535/5,65535/5,65535/5),win=jScanPanel
			Button/Z ScanButton,title="Scan",fColor=(65535/5,65535/5,65535/5),win=jScanPanel
			Button/Z grabStackButton,title="Acquire stack",fColor=(65535/5,65535/5,65535/5),win=jStackPanel
			jSc_MakeProgressBar(0,"Loop progress")
			jSc_loop_newRun()
		endif
	else
		Beep
		print "You have to choose a save path first!"
		Abort "You have to choose a save path first!"
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Tidy up after running a loop

Function jSc_endLoopRun()

	NVAR		jSc_max_xAmp
	NVAR		jSc_max_yAmp
	NVAR		jSc_LoopFlag
	
	ctrlNamedBackground jSc_loopBack,kill
	ctrlNamedBackground jSc_loopProgBack,kill
	jSc_KillProgressBar()
	jSc_LoopFlag = 0
	Button/Z LoopButton,title="Loop",fColor=(65535,0,65535),win=jScanPanel						// Revert loop button
	Button/Z GrabButton,title="Grab",fColor=(0,0,65535),win=jScanPanel
	Button/Z ScanButton,title="Scan",fColor=(0,65535,0),win=jScanPanel
	Button/Z grabStackButton,title="Acquire stack",fColor=(0,0,65535),win=jStackPanel
	// Note to self: The below should NOT be executed because the last Grab is still executing in the background
//	jSc_closeShutter()
//	jSc_stopWaveformAndScan()
//	jSc_parkLaser(jSc_max_xAmp,jSc_max_yAmp)
//	jSc_recoverAfterScan()			// the above commented-out lines are taken care if in this function call

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Setup the next grab in a loop

Function jSc_loop_newRun()

	NVAR		jSc_loopPeriod

	NVAR		jSc_ProgVar
	NVAR		jSc_ProgTarget
	NVAR		jSc_ProgPeriod

	// Start loop background task
	ctrlNamedBackground jSc_loopBack,period=(60*jSc_loopPeriod),proc=jSc_loopBackProc			// This task executes a new Grab every loop period
	ctrlNamedBackground jSc_loopBack,start														// Not sure why the below two lines do not work, but this does
//	ctrlNamedBackground jSc_loopBack,start=(60*jSc_loopPeriod)
//	jSc_doGrab()
	
	// Reset progress bar variables and start progress bar background task
	jSc_ProgVar = 0
	jSc_ProgTarget = jSc_loopPeriod
	ctrlNamedBackground jSc_loopProgBack,period=(60*jSc_ProgPeriod),proc=jSc_LoopProgBackProc	// This task updates the progress bar
	ctrlNamedBackground jSc_loopProgBack,start

End

//////////////////////////////////////////////////////////////////////////////////
//// Loop background task

Function jSc_loopBackProc(s)
	STRUCT WMBackgroundStruct &s

	NVAR		jSc_LoopFlag
	NVAR		jSc_loopPeriod
	NVAR		jSc_loopCounter
	NVAR		jSc_nLoops
	
	NVAR		jSc_VerboseMode
	
	jSc_loopCounter += 1
	
	if (jSc_VerboseMode)
		print "{jSc_loopBackProc} reporting that jSc_loopCounter =",jSc_loopCounter
	endif
	
	if (jSc_loopCounter>jSc_nLoops)		// This should never execute, because jSc_LoopProgBackProc runs jSc_endLoopRun before jSc_loopBackProc does, but keep this here as a safety
		jSc_endLoopRun()
	endif

	if (jSc_LoopFlag)					// If still looping, start next acquisition
		jSc_doGrab()
	endif

	Variable	retVal	
	if (jSc_LoopFlag)
		retVal = 0
	else
		retVal = 1
	endif

	return retVal

End

//////////////////////////////////////////////////////////////////////////////////
//// Update the Progress Bar during loop to show that something is happening

Function jSc_LoopProgBackProc(s)
	STRUCT WMBackgroundStruct &s

	NVAR		jSc_ProgVar
	NVAR		jSc_ProgTarget
	NVAR		jSc_ProgPeriod
	
	NVAR		jSc_loopCounter
	NVAR		jSc_nLoops
	NVAR		jSc_LoopFlag
	NVAR		jSc_GrabFlag

	NVAR		jSc_VerboseMode

	jSc_ProgVar += jSc_ProgPeriod
	if (jSc_ProgVar>jSc_ProgTarget)
		jSc_ProgVar = 0
	endif
	
	if (jSc_VerboseMode)
		print "{jSc_LoopProgBackProc} reporting that jSc_ProgVar =",jSc_ProgVar
	endif
	
	if (!jSc_GrabFlag)						// If grab is done...
		if (jSc_loopCounter>=jSc_nLoops)		// ...and loop is exceeded...
			jSc_endLoopRun()				// ...then shut down loop.
		endif
	endif

	jSc_UpdateProgressBar(jSc_ProgVar/jSc_ProgTarget,"Current loop iteration: "+num2str(jSc_ProgVar)+" of "+num2str(jSc_ProgTarget)+" s.")

	Variable	retVal	
	if (jSc_LoopFlag)
		retVal = 0
	else
		retVal = 1
	endif

	return retVal

End

//////////////////////////////////////////////////////////////////////////////////
//// Update the Progress Bar during stimulation to show that something is happening

Function jSc_StimBackProc(s)
	STRUCT WMBackgroundStruct &s

	NVAR		jSc_ProgVar
	NVAR		jSc_ProgTarget
	NVAR		jSc_ProgPeriod
	
	NVAR		jSc_stimFlag

	NVAR		jSc_VerboseMode

	jSc_ProgVar += jSc_ProgPeriod
	if (jSc_ProgVar>jSc_ProgTarget)
		jSc_ProgVar = 0
	endif
	
	if (jSc_VerboseMode)
		print "{jSc_StimBackProc} reporting that jSc_ProgVar =",jSc_ProgVar
	endif
	
	jSc_UpdateProgressBar(jSc_ProgVar/jSc_ProgTarget,"Stimulation progress: "+num2str(jSc_ProgVar)+" of "+num2str(jSc_ProgTarget)+" s.")

	Variable	retVal	
	if (jSc_stimFlag)
		retVal = 0
	else
		retVal = 1
	endif

	return retVal

End

//////////////////////////////////////////////////////////////////////////////////
//// Simulate a simple progress bar window

Function jSc_MakeProgressBar(TheValue,TheText)
	Variable	TheValue
	String		TheText

	Variable	debugFlag = 0
	if (theValue == -101)
		debugFlag = 1
	endif

	Variable	xPos = 300
	Variable	yPos = 273
	Variable	Width = 320
	Variable	rowHeight = 20+4
	Variable	Height = 4+rowHeight*2

	String/G	jSc_Progress_MessageStr = TheText
	Variable/G	jSc_Progress_val = TheValue
	
	Variable	ScSc = PanelResolution("")/ScreenResolution

	xPos *= ScSc
	yPos *= ScSc

	Variable frameStyle = 0	
	if (JT_thisIsWindows())
		frameStyle = 2
	endif

	jSc_KillProgressBar()
	NewPanel/FLT=(1-debugFlag)/W=(xPos,yPos,xPos+Width,yPos+Height)/k=1
	DoWindow/C jSc_ProgressWin
	ModifyPanel cbRGB=(65534,65534,65534)

	ValDisplay theBar,pos={4,4+rowHeight*0},size={Width-4-4,rowHeight-4},title="Progress: "
	ValDisplay theBar,labelBack=(65535,65535,65535),fSize=12,frame=(frameStyle)
	ValDisplay theBar,limits={0,1,0},barmisc={0,0},mode= 3,value=#"root:jSc_Progress_val"

	SetVariable theText,pos={4,4+rowHeight*1},size={Width-4-4,rowHeight-4},title=" "
	SetVariable theText,labelBack=(65535,65535,65535),fSize=12,frame=0
	SetVariable theText,noedit= 1,bodyWidth=(Width-4-4),value=root:jSc_Progress_MessageStr

	DoUpdate/W=jSc_ProgressWin/E=1
	if (!(debugFlag))
		SetActiveSubwindow _endfloat_
	endif

	// Autoposition the progress bar window next to relevant panel	
	AutoPositionWindow/E/M=1/R=jScanPanel jSc_ProgressWin

End

Function jSc_KillProgressBar()

	DoWindow jSc_ProgressWin
	if (V_flag)
		DoWindow/K/W=jSc_ProgressWin jSc_ProgressWin
	endif

End

Function jSc_UpdateProgressBar(TheValue,TheText)
	Variable		TheValue
	String		TheText

	SVAR		jSc_Progress_MessageStr
	NVAR		jSc_Progress_val

	jSc_Progress_val = TheValue
	jSc_Progress_MessageStr = TheText

	DoUpdate/W=jSc_ProgressWin/E=1

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Save after uncaging run

Function jSc_saveStimRun()

	NVAR		jSc_stim2pZapFlag

	WAVE/Z		theGrid
	WAVE/Z		nGrid
	WAVE/Z		yGrid
	WAVE/Z		xGrid
	WAVE		jSc_xVw
	WAVE		jSc_yVw
	
	WAVE		jSc_Ch1raw											// Only two channels are acquired during stimulation
	WAVE		jSc_Ch2raw
	
	SVAR		jSc_rig
	
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp

	NVAR		jSc_scanAngle
	NVAR		jSc_stim_xSize
	NVAR		jSc_stim_ySize
	NVAR		jSc_stim_dwellTime
	NVAR		jSc_stim_shutterTime
	NVAR		jSc_stim_nPulses
	NVAR		jSc_stim_PulsePrePad
	NVAR		jSc_stim_freq
	NVAR		jSc_unc_flyTime
	NVAR		jSc_stim_sampFreq
	NVAR		jSc_stim_Suffix
	
	NVAR		jSc_stgX
	NVAR		jSc_stgY
	NVAR		jSc_stgZ
	
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	
	Variable		MP_is_running = 0
	if (exists("root:MP:IO_Data:WaveNamesIn1"))						// Kludge check to see if MultiPatch is running
		MP_is_running = 1
	endif
	SVAR/Z		MP_bName1 = root:MP:IO_Data:WaveNamesIn1
	SVAR/Z		MP_bName2 = root:MP:IO_Data:WaveNamesIn2
	SVAR/Z		MP_bName3 = root:MP:IO_Data:WaveNamesIn3
	SVAR/Z		MP_bName4 = root:MP:IO_Data:WaveNamesIn4
	NVAR/Z		MP_suffix1 = root:MP:IO_Data:StartAt1
	NVAR/Z		MP_suffix2 = root:MP:IO_Data:StartAt2
	NVAR/Z		MP_suffix3 = root:MP:IO_Data:StartAt3
	NVAR/Z		MP_suffix4 = root:MP:IO_Data:StartAt4
	
	jSc_COM_getPos()												// Refresh XYZ stage coordinates
	
	String/G	jSc_waveNoteStr = ""
	jSc_waveNoteStr += "jScan (c) Jesper Sjostrom 2014\r"
	jSc_waveNoteStr += "rig="+jSc_rig+"\r"
	jSc_waveNoteStr += "jSc_xAmp="+num2str(jSc_xAmp)+"\r"
	jSc_waveNoteStr += "jSc_yAmp="+num2str(jSc_yAmp)+"\r"
	jSc_waveNoteStr += "scanAngle="+num2str(jSc_scanAngle)+"\r"
	jSc_waveNoteStr += "xSize="+num2str(jSc_stim_xSize)+"\r"
	jSc_waveNoteStr += "ySize="+num2str(jSc_stim_ySize)+"\r"
	jSc_waveNoteStr += "dwellTime="+num2str(jSc_stim_dwellTime)+"\r"
	jSc_waveNoteStr += "shutterTime="+num2str(jSc_stim_shutterTime)+"\r"
	jSc_waveNoteStr += "nPulses="+num2str(jSc_stim_nPulses)+"\r"
	jSc_waveNoteStr += "PulsePrePad="+num2str(jSc_stim_PulsePrePad)+"\r"
	jSc_waveNoteStr += "freq="+num2str(jSc_stim_freq)+"\r"
	jSc_waveNoteStr += "flyTime="+num2str(jSc_unc_flyTime)+"\r"
	jSc_waveNoteStr += "sampFreq="+num2str(jSc_stim_sampFreq)+"\r"
	jSc_waveNoteStr += "date="+Secs2Date(DateTime,-2)+"\r"
	jSc_waveNoteStr += "time="+Secs2Time(DateTime,3)+"\r"
	jSc_waveNoteStr += "x="+num2str(jSc_stgX)+"\r"
	jSc_waveNoteStr += "y="+num2str(jSc_stgY)+"\r"
	jSc_waveNoteStr += "z="+num2str(jSc_stgZ)+"\r"
	jSc_waveNoteStr += "MP_is_running="+num2str(MP_is_running)+"\r"
	jSc_waveNoteStr += "jSc_xAmp="+num2str(jSc_xAmp)+"\r"
	jSc_waveNoteStr += "jSc_yAmp="+num2str(jSc_yAmp)+"\r"
	Variable	n = 4
	Variable	i
	i = 0
	do
		SVAR/Z		MP_bName = $("root:MP:IO_Data:WaveNamesIn"+num2str(i+1))
		NVAR/Z		MP_suffix = $("root:MP:IO_Data:StartAt"+num2str(i+1))
		if (MP_is_running)																		// Store info to simplify cross-referencing waves acquired with MultiPatch in data analysis panel
			jSc_waveNoteStr += "MP_in"+num2str(i+1)+"="+MP_bName+"\r"
			jSc_waveNoteStr += "MP_suffix"+num2str(i+1)+"="+num2str(MP_suffix-1)+"\r"			// Note the -1 to account for the fact that MP is counting up suffix before wave is saved!
		endif
		i += 1
	while(i<n)
	
	String		suffixStr = "_"+JT_num2digstr(4,jSc_stim_Suffix)								// Note: underscore in suffix string!
	print "Saving uncaging run data at time "+time()+" with suffix \""+suffixStr+"\""
	
	if (jSc_stim2pZapFlag)
		Duplicate/O jSc_pointsX,$("jSc_pointsX"+suffixStr)
		Duplicate/O jSc_pointsY,$("jSc_pointsY"+suffixStr)
		Duplicate/O jSc_pointsN,$("jSc_pointsN"+suffixStr)
	else
		Duplicate/O theGrid,$("theGrid"+suffixStr)
		Duplicate/O nGrid,$("nGrid"+suffixStr)
		Duplicate/O yGrid,$("yGrid"+suffixStr)
		Duplicate/O xGrid,$("xGrid"+suffixStr)
	endif
	Duplicate/O jSc_xVw,$("jSc_xVw"+suffixStr)
	Duplicate/O jSc_yVw,$("jSc_yVw"+suffixStr)
	Duplicate/O jSc_shutterWave,$("jSc_shutterWave"+suffixStr)
	Duplicate/O jSc_Ch1raw,$("jSc_Ch1raw"+suffixStr)
	Duplicate/O jSc_Ch2raw,$("jSc_Ch2raw"+suffixStr)
	
	if (jSc_stim2pZapFlag)
		Note $("jSc_pointsX"+suffixStr),jSc_waveNoteStr
		Note $("jSc_pointsY"+suffixStr),jSc_waveNoteStr
		Note $("jSc_pointsN"+suffixStr),jSc_waveNoteStr
	else
		Note $("theGrid"+suffixStr),jSc_waveNoteStr
		Note $("nGrid"+suffixStr),jSc_waveNoteStr
		Note $("yGrid"+suffixStr),jSc_waveNoteStr
		Note $("xGrid"+suffixStr),jSc_waveNoteStr
	endif
	Note $("jSc_xVw"+suffixStr),jSc_waveNoteStr
	Note $("jSc_yVw"+suffixStr),jSc_waveNoteStr
	Note $("jSc_shutterWave"+suffixStr),jSc_waveNoteStr
	Note $("jSc_Ch1raw"+suffixStr),jSc_waveNoteStr
	Note $("jSc_Ch2raw"+suffixStr),jSc_waveNoteStr
	
	if (jSc_stim2pZapFlag)
		Save/O/C/P=jScPath $("jSc_pointsX"+suffixStr)
		Save/O/C/P=jScPath $("jSc_pointsY"+suffixStr)
		Save/O/C/P=jScPath $("jSc_pointsN"+suffixStr)
	else
		Save/O/C/P=jScPath $("theGrid"+suffixStr)
		Save/O/C/P=jScPath $("nGrid"+suffixStr)
		Save/O/C/P=jScPath $("yGrid"+suffixStr)
		Save/O/C/P=jScPath $("xGrid"+suffixStr)
	endif
	Save/O/C/P=jScPath $("jSc_xVw"+suffixStr)
	Save/O/C/P=jScPath $("jSc_yVw"+suffixStr)
	Save/O/C/P=jScPath $("jSc_shutterWave"+suffixStr)
	Save/O/C/P=jScPath $("jSc_Ch1raw"+suffixStr)
	Save/O/C/P=jScPath $("jSc_Ch2raw"+suffixStr)
	
	jSc_stim_Suffix += 1
	if (jSc_stim_Suffix>9999)
		Beep
		jSc_stim_Suffix = 1
		print "WARNING at "+time()+"!!!" 
		print "jSc_stim_Suffix counter reached 10000 and was wrapped around back to 1 -- old sweeps may be overwritten!!!"
	endif

	if (jSc_stim2pZapFlag)
		KillWaves/Z  $("jSc_pointsX"+suffixStr)
		KillWaves/Z  $("jSc_pointsY"+suffixStr)
		KillWaves/Z  $("jSc_pointsN"+suffixStr)
	else
		KillWaves/Z  $("theGrid"+suffixStr)
		KillWaves/Z  $("nGrid"+suffixStr)
		KillWaves/Z  $("yGrid"+suffixStr)
		KillWaves/Z  $("xGrid"+suffixStr)
	endif
	KillWaves/Z  $("jSc_xVw"+suffixStr)
	KillWaves/Z  $("jSc_yVw"+suffixStr)
	KillWaves/Z  $("jSc_shutterWave"+suffixStr)
	KillWaves/Z  $("jSc_Ch1raw"+suffixStr)
	KillWaves/Z  $("jSc_Ch2raw"+suffixStr)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Tidy up after running the uncaging

Function jSc_endStimRun()

	NVAR		jSc_max_xAmp
	NVAR		jSc_max_yAmp
	NVAR		jSc_stimFlag
	
	ctrlNamedBackground jSc_stimBack,kill
	ctrlNamedBackground jSc_stimWaitBack,kill
	jSc_KillProgressBar()
	jSc_stimFlag = 0
	Button/Z zapRunButton,title="Run 2p zap pattern",fColor=(0,0,65535),win=j2pZapPanel
	Button/Z uncRunButton,title="Run uncaging pattern",fColor=(0,0,65535),win=jUncagePanel
	jSc_closeShutter()
	jSc_stopWaveformAndScan()
	jSc_parkLaser(jSc_max_xAmp,jSc_max_yAmp)		// Park laser beam in some godforsaken corner to prevent burning the prep should shutter be left open by mistake

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Setup the next run of uncaging when repeating

Function jSc_stopWaveformAndScan()

	SVAR		jSc_inDevStr
	SVAR		jSc_outDevStr
	String		dummyStr
	NVAR		jSc_VerboseMode

#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: jSc_stopWaveformAndScan simulated"
	endif
	ctrlNamedBackground jSc_demoBack,kill			// Kill the faked end-of-scan hook, just to be on the safe side
#else
	if (fDAQmx_WaveformStop(jSc_inDevStr)>0)
		dummyStr = fDAQmx_ErrorString()				// Stopping something that is not running gives rise to an error that is dumped to the error stack, so empty that stack just in case.
	endif
	if (fDAQmx_ScanStop(jSc_outDevStr)>0)
		dummyStr = fDAQmx_ErrorString()
	endif
#endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Setup the next run of stimulation when repeating

Function jSc_stim_newRun()

	NVAR		jSc_ProgPeriod
	NVAR		jSc_ProgVar

	jSc_openShutter()
	jSc_setupStimAO()
	jSc_setupStimAI()								// With stimulation, there is always data acquisition

	// Reset progress bar variables and start progress bar background task
	jSc_ProgVar = 0
	NVAR		jSc_ProgTarget
	WAVE		jSc_xVw
	jSc_ProgTarget = rightx(jSc_xVw)
	ctrlNamedBackground jSc_stimBack,period=(60*jSc_ProgPeriod),proc=jSc_StimBackProc
	ctrlNamedBackground jSc_stimBack,start

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Begin stimulation waveform generation

Function jSc_setupStimAI()

	WAVE		jSc_GateWave							// Use GateWave when sending from imaging board, use ShutterWave when sending from ePhys board, 'coz different number of samples
	
	SVAR		jSc_inDevStr

	NVAR		jSc_vRange1
	NVAR		jSc_vRange2
	
	NVAR		jSc_VerboseMode

	String		wStr = ""

	// Use jSc_GateWave as template for jSc_Ch1raw & jSc_Ch2raw. This works well as long as there is no temporal binning, so ignore jSc_pixelBin
	// Also note that channels 1 and 2 are always acquired, by default
	Duplicate/O jSc_GateWave,jSc_Ch1raw
	wStr += "jSc_Ch1raw,0,-"+num2str(0)+","+num2str(jSc_vRange1)+";"
	Duplicate/O jSc_GateWave,jSc_Ch2raw
	wStr += "jSc_Ch2raw,1,-"+num2str(0)+","+num2str(jSc_vRange2)+";"

#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: DAQmx_Scan simulated"
	endif
#else
//	DAQmx_Scan/DEV=jSc_inDevStr/BKG/ERRH="jSc_stimAIErrorHook()"/EOSH="jSc_stimAIEndOfScanHook()"/AVE=(jSc_pixelBin) WAVES=wStr
	DAQmx_Scan/DEV=jSc_inDevStr/BKG/ERRH="jSc_stimAIErrorHook()"/EOSH="jSc_stimAIEndOfScanHook()" WAVES=wStr			// Does not use jSc_pixelBin for now, upsampling will have to wait
#endif

End

Function jSc_stimAIErrorHook()
	
	print "{jSc_stimAIErrorHook} Problem during scan, aborted..."
	jSc_printError()

End

Function jSc_stimAIEndOfScanHook()

	NVAR		jSc_VerboseMode
	NVAR		jSc_stimRunCounter
	NVAR		jSc_maxStimRuns
	NVAR		jSc_reRandomize
	NVAR		jSc_stim2pZapFlag
	NVAR		jSc_stim_mustRerandom
	NVAR		jSc_ProgPeriod
	NVAR		jSc_ProgVar
	NVAR		jSc_stimWait
	
	jSc_closeShutter()
	jSc_stimRunCounter += 1

	if (jSc_VerboseMode)
		print "{jSc_stimAOEndOfScanHook}"
	endif
	jSc_saveStimRun()
	if (jSc_stimRunCounter>=jSc_maxStimRuns)
		jSc_endStimRun()
	else
		// Kill monitoring background task, as we do not need it in between runs
		ctrlNamedBackground jSc_stimBack,kill
		// Background task to manage wait between uncaging runs when repeating
		jSc_ProgVar = 0
		ctrlNamedBackground jSc_stimWaitBack,period=(60*jSc_ProgPeriod),proc=jSc_stimWaitBackProc,start//=(ticks+60*jSc_stimWait)
		// While waiting for next run, re-randomize the uncaging points if so desired, but never do this if 2p Zap
		if (!(jSc_stim2pZapFlag))
			if ((jSc_reRandomize) %| (jSc_stim_mustRerandom))
				jSc_UpdateProgressBar(0,"Re-randomizing uncaging points...")
				jSc_SetupPseudoRandom()
			else
				jSc_uncPatt2voltages()	// User may have changed rotation since last time, so reconvert pattern to voltages
			endif
		endif
		jSc_UpdateProgressBar(jSc_ProgVar/jSc_stimWait,"Waiting: "+num2str(jSc_ProgVar)+" of "+num2str(jSc_stimWait)+" s.")
	endif

End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Begin stimulation waveform generation

Function jSc_setupStimAO()

	SVAR		jSc_outDevStr
	SVAR		jSc_inDevStr
	WAVE		jSc_xVw
	WAVE		jSc_yVw
	WAVE		jSc_gateWave
	NVAR		jSc_stim2pZapFlag			// Note to self: gateWave only sent if checked on j2pZapPanel
	NVAR		jSc_gateOut
	NVAR		jSc_VerboseMode
	
	String/G		jSc_AOString = ""
	jSc_AOString += "jSc_xVw, 0;"
	jSc_AOString += "jSc_yVw, 1;"
	
	doWindow j2pZapPanel
	if (V_flag)
		controlInfo/W=j2pZapPanel sendGateCheck
		if (V_Value)
			if (jSc_stim2pZapFlag)
				jSc_AOString += "jSc_gateWave, "+num2str(jSc_gateOut)+";"
			endif
		endif
	endif
	
#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: jSc_setupStimAO simulated"
	endif
#else
	// Defaults to running on AO sample clock unless you state otherwise
//	DAQmx_WaveformGen/DEV=jSc_outDevStr/ERRH="jSc_AOErrorHook()"/EOSH="jSc_stimAOEndOfScanHook()"/NPRD=1/STRT jSc_AOString		// jSc_stimAOEndOfScanHook now deprecated, use jSc_stimAIEndOfScanHook instead
	DAQmx_WaveformGen/DEV=jSc_outDevStr/ERRH="jSc_AOErrorHook()"/NPRD=1/TRIG={"/"+jSc_inDevStr+"/ai/starttrigger"}/CLK={"/"+jSc_inDevStr+"/ai/sampleclock",1} jSc_AOString
#endif

	if (jSc_VerboseMode)
		print "{jSc_setupStimAO} Send string:"+jSc_AOString
	endif

End

Function jSc_stimAOErrorHook()
	
	print "{jSc_stimAOErrorHook} Problem during uncaging waveform generation, aborted..."
	jSc_printError()

End

// DEPRECATED, use jSc_stimAIEndOfScanHook instead

//Function jSc_stimAOEndOfScanHook()
//	
//	NVAR		jSc_VerboseMode
//	NVAR		jSc_stimRunCounter
//	NVAR		jSc_maxStimRuns
//	NVAR		jSc_stimWait
//	NVAR		jSc_reRandomize
//	NVAR		jSc_stim2pZapFlag
//	NVAR		jSc_stim_mustRerandom
//	NVAR		jSc_ProgPeriod
//	NVAR		jSc_ProgVar
//	NVAR		jSc_stimWait
//	
//	jSc_closeShutter()
//	jSc_stimRunCounter += 1
//
//	if (jSc_VerboseMode)
//		print "{jSc_stimAOEndOfScanHook}"
//	endif
//	jSc_saveStimRun()
//	if (jSc_stimRunCounter>=jSc_maxStimRuns)
//		jSc_endStimRun()
//	else
//		// Kill monitoring background task, as we do not need it in between runs
//		ctrlNamedBackground jSc_stimBack,kill
//		// Background task to manage wait between uncaging runs when repeating
//		jSc_ProgVar = 0
//		ctrlNamedBackground jSc_stimWaitBack,period=(60*jSc_ProgPeriod),proc=jSc_stimWaitBackProc,start//=(ticks+60*jSc_stimWait)
//		// While waiting for next run, re-randomize the uncaging points if so desired, but never do this if 2p Zap
//		if (!(jSc_stim2pZapFlag))
//			if ((jSc_reRandomize) %| (jSc_stim_mustRerandom))
//				jSc_UpdateProgressBar(0,"Re-randomizing uncaging points...")
//				jSc_SetupPseudoRandom()
//			else
//				jSc_uncPatt2voltages()	// User may have changed rotation since last time, so reconvert pattern to voltages
//			endif
//		endif
//		jSc_UpdateProgressBar(jSc_ProgVar/jSc_stimWait,"Waiting: "+num2str(jSc_ProgVar)+" of "+num2str(jSc_stimWait)+" s.")
//	endif
//
//End

//////////////////////////////////////////////////////////////////////////////////
//// Uncaging background task to manage the wait between
//// uncaging runs when repeating

Function jSc_stimWaitBackProc(s)
	STRUCT WMBackgroundStruct &s

	NVAR		jSc_stimFlag
	NVAR		jSc_stimWait
	NVAR		jSc_ProgVar
	NVAR		jSc_stimFlag
	NVAR		jSc_ProgPeriod
	
	NVAR		jSc_VerboseMode

	Variable	retVal = 0

	if (jSc_VerboseMode)
		print "{jSc_stimWaitBackProc} reporting that jSc_ProgVar =",jSc_ProgVar
	endif
	
	jSc_ProgVar += jSc_ProgPeriod
	jSc_UpdateProgressBar(jSc_ProgVar/jSc_stimWait,"Waiting: "+num2str(jSc_ProgVar)+" of "+num2str(jSc_stimWait)+" s.")
	if (jSc_ProgVar>=jSc_stimWait)
		jSc_ProgVar = 0
		ctrlNamedBackground jSc_stimWaitBack,stop		// background stops itself doubly!
		jSc_stim_newRun()								// Start new run
		retVal = 1
	endif
	
	return retVal

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set up pseudorandom uncaging pattern

Function jSc_uncCreateProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			jSc_SetupPseudoRandom()
			break
	endswitch

	return 0
End

Function jSc_SetupPseudoRandom()

	NVAR		jSc_stim_xSize
	NVAR		jSc_stim_ySize
	NVAR		jSc_unc_gap
	NVAR		jSc_reRandomize
	NVAR		jSc_stim_mustRerandom

	Print "=== Parameters ==="
	print "Time is "+time()+"."
	Print "\tSetting up a "+num2str(jSc_stim_xSize)+"-by-"+num2str(jSc_stim_ySize)+" grid"
	Print "\tGap: "+num2str(jSc_unc_gap)

	if ((jSc_reRandomize) %| (jSc_stim_mustRerandom))
		Print "\tRandomizing before making grid."
		jSc_makeRandUncPatt()
	else
		Print "\tNo randomization before making grid; reusing previous round."
	endif
	jSc_uncPatt2voltages()
	jSc_MakePseudoUncGraph()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make random uncaging pattern

Function jSc_makeRandUncPatt()

	NVAR		xSpots = jSc_stim_xSize
	NVAR		ySpots = jSc_stim_ySize
	NVAR		jSc_stim_mustRerandom
	
	Make/O/N=(xSpots,ySpots) theGrid
	Make/O/N=(xSpots*ySpots) xGrid,yGrid,nGrid

	WAVE		theGrid
	WAVE		xGrid
	WAVE		yGrid
	WAVE		nGrid
	
	Variable/G	jSc_nPoints = xSpots*ySpots
	
	Variable	xLoc,yLoc
	Variable	xLastLoc,yLastLoc
	xLastLoc = Inf
	yLastLoc = Inf
	NVAR		Gap = jSc_unc_gap
	Variable	TooClose

	Variable	i,j
	Variable	maxIter = jSc_nPoints*5
	Variable	AbortAndRetry
	Variable	nTries = 0
	Variable	maxTries = 20
	
	// Create the uncaging pattern
	do
		AbortAndRetry = 0
		nTries += 1
		theGrid = -1
		xGrid = 0
		yGrid = 0
		nGrid = 0
		i = 0
		do
			j = 0
			do
				xLoc = Floor((eNoise(0.5)+0.5)*xSpots)
				yLoc = Floor((eNoise(0.5)+0.5)*ySpots)
				TooClose = ( (abs(xLoc-xLastLoc)<=Gap) %& (abs(yLoc-yLastLoc)<=Gap) )
				j += 1
				if (j>maxIter)
					Print "Painted myself into a corner -- can't find solution. Retry..."
					AbortAndRetry = 1
					Break
				endif
			while ((theGrid[xLoc][yLoc]!=-1) %| (TooClose))
			if (AbortAndRetry)
				Break
			endif
			theGrid[xLoc][yLoc] = i
			xGrid[i] = xLoc
			yGrid[i] = yLoc
			nGrid[i] = i+1
			xLastLoc = xLoc
			yLastLoc = yLoc
			i += 1
		while(i<jSc_nPoints)
		if (nTries>maxTries)
			print "Could not find a solution after "+num2str(nTries)+" attempts. Your settings are likely wrong. Change them and try again."
			Abort "Could not find a solution after "+num2str(nTries)+" attempts."
		endif
	while(AbortAndRetry)
	Print "Required "+num2str(nTries)+" attempts before finding solution..."
	jSc_stim_mustRerandom = 0
	
End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Convert the grid uncaging pattern to voltage values

Function jSc_uncPatt2voltages()

	NVAR		xSpots = jSc_stim_xSize
	NVAR		ySpots = jSc_stim_ySize
	
	WAVE		theGrid
	WAVE		xGrid
	WAVE		yGrid
	WAVE		nGrid
	
	Variable/G	jSc_nPoints = xSpots*ySpots

	// Convert the uncaging pattern to voltage values
	NVAR		jSc_mspl
	NVAR		jSc_flyback
	NVAR		jSc_pxpl
	NVAR		jSc_lnpf
	NVAR		jSc_xAmp
	NVAR		jSc_yAmp
	NVAR		jSc_xPad
	
	NVAR		jSc_ZoomFactor

	NVAR		jSc_stim_sampFreq
	NVAR		jSc_unc_flyTime
	NVAR		jSc_stim_dwellTime
	NVAR		jSc_stim_shutterTime
	NVAR		jSc_stim_nPulses
	NVAR		jSc_stim_PulsePrePad
	NVAR		jSc_stim_freq
	
	NVAR		jSc_stim_shutterOpen
	NVAR		jSc_stim_shutterClosed
	
	NVAR		jSc_deltaT1
	NVAR		jSc_deltaT2
	
	SVAR		jSc_noSpikeList
	SVAR		jSc_addOffsetList
	NVAR		jSc_spikeOffset
	Variable	currSpikeOffset = 0
	
	NVAR		jSc_VerboseMode

	Variable	dwellPoints = jSc_stim_dwellTime*1e-3*jSc_stim_sampFreq							// Number of sample points for each dwell time
	Variable	flyPoints = jSc_unc_flyTime*1e-3*jSc_stim_sampFreq								// Number of sample points for each fly time
	Variable	totDwellPoints = dwellPoints+flyPoints											// Total number of sample points for each uncaging location
	Variable	nSamplePoints = totDwellPoints*jSc_nPoints										// Total number of sample points for entire sweep
	Variable	wDur = nSamplePoints/jSc_stim_sampFreq											// Uncaging sweep duration from points (s)
	Variable	calc_wDur = (jSc_stim_dwellTime+jSc_unc_flyTime)*1e-3*jSc_nPoints				// Uncaging sweep duration from time (s)
	Variable	prePadPoints = jSc_stim_PulsePrePad*1e-3*jSc_stim_sampFreq
	Variable	stimPoints = jSc_stim_shutterTime*1e-3*jSc_stim_sampFreq
	Variable	freqInPoints = Round(jSc_stim_sampFreq/jSc_stim_freq)
	if (jSc_VerboseMode)
		print "Actual uncaging sweep duration:",wDur,"s"
		print "Calculated sweep duration:",calc_wDur,"s (any mismatch is due to rounding errors)"
		print "The uncaging sweep runs at "+num2str(jSc_stim_sampFreq/1e3)+" kHz sampling frequency."
		print "Total number of sample points in uncaging sweep:",nSamplePoints
		print "\tNumber of sample points for each uncaging location:",totDwellPoints
		print "\t\tNumber of sample points spent dwelling:",dwellPoints
		print "\t\tNumber of sample points spent flying:",flyPoints
		print "\t\tNumber of prepad points before uncaging:",prePadPoints
		print "\t\tNumber of points per uncaging pulse:",stimPoints
		print "\t\tNumber of pulses:",jSc_stim_nPulses
		if (jSc_stim_nPulses>1)
			print "\t\tUncaging pulse starting points in a train are separated by this many points:",freqInPoints
		else
			print "\t\tThere is only one uncaging pulse, so uncaging pulse frequency does not apply."
		endif
	endif
	Make/O/N=(nSamplePoints) jSc_xVw,jSc_yVw,jSc_shutterWave,jSc_blankWave
	jSc_xVw = 0
	jSc_yVw = 0
	jSc_shutterWave = jSc_stim_shutterClosed
	jSc_blankWave = 0
	Variable	kx,ky,mx,my
	Variable	xV,yV
	NVAR	jSc_max_xAmp
	NVAR	jSc_max_yAmp
	Variable	xV_old = jSc_max_xAmp		// Assuming the laser beam first starts out at these park values (was 0 before)
	Variable	yV_old = jSc_max_yAmp		// Assuming the laser beam first starts out at these park values (was 0 before)
	Variable	i,j

	//// Set up to create postsynaptic current injection waves
	NVAR	SampleFreq =			root:MP:SampleFreq					// Sampling frequency [Hz]
	NVAR	SealTestPad1 = 		root:MP:SealTestPad1					// Sealtest parameters are taken from the WaveCreator
	NVAR	SealTestPad2 = 		root:MP:SealTestPad2
	NVAR	SealTestDur = 		root:MP:SealTestDur
	if (!(Exists("SpTm_wDur")))
		SpTm2WavesSetup()												// Set up the SpTm2Waves procedure if not already done
	endif
	Make/O/N=(0) SpikeTimes_1											// Erase old spike times
	Make/O/N=(0) SpikeTimes_2
	Make/O/N=(0) SpikeTimes_3
	Make/O/N=(0) SpikeTimes_4
	Variable tStep = -(jSc_deltaT1-jSc_deltaT2)/(jSc_nPoints-1)			// Reversed sign convention for dT, 30 Aug 2018, JSj

	//// Create x and y command voltages as well as the shutter control
	i = 0
	do
		// Fly to new point
		xV = (xGrid[i]-xSpots/2+0.5) * 2/(xSpots-1) * jSc_xAmp * (xSpots-1)/xSpots / jSc_ZoomFactor
		yV = (yGrid[i]-ySpots/2+0.5) * 2/(ySpots-1) * jSc_yAmp * (ySpots-1)/ySpots / jSc_ZoomFactor
		kx = (xV-xV_old)/(flyPoints+1)
		ky = (yV-yV_old)/(flyPoints+1)
		mx = xV_old
		my = yV_old
		jSc_xVw[i*totDwellPoints,i*totDwellPoints+flyPoints-1] = kx*(p-i*totDwellPoints+1)+mx
		jSc_yVw[i*totDwellPoints,i*totDwellPoints+flyPoints-1] = ky*(p-i*totDwellPoints+1)+my
		// Dwell at point
		jSc_xVw[i*totDwellPoints+flyPoints,i*totDwellPoints+totDwellPoints-1] = xV
		jSc_yVw[i*totDwellPoints+flyPoints,i*totDwellPoints+totDwellPoints-1] = yV
		// Add uncaging pulses
		j = 0
		do
			jSc_shutterWave[i*totDwellPoints+prePadPoints+freqInPoints*j,i*totDwellPoints+prePadPoints+freqInPoints*j+stimPoints-1] = jSc_stim_shutterOpen
			j += 1
		while(j<jSc_stim_nPulses)
		// Remember timing of postsynaptic current injection
		if (str2num(stringfromlist(i,jSc_noSpikeList))==0)		// ... but only if user wants a spike at this location
			currSpikeOffset = jSc_spikeOffset*str2num(stringfromlist(i,jSc_addOffsetList))	// Add spike offset
			SpikeTimes_1[numpnts(SpikeTimes_1)] = {(i*totDwellPoints+prePadPoints)/jSc_stim_sampFreq+(tStep*i+jSc_deltaT1+currSpikeOffset)*1e-3}		// Reversed sign convention for dT, 30 Aug 2018, JSj
		endif
		// Remember this point for next flight
		xV_old = xV
		yV_old = yV
		i += 1
	while(i<jSc_nPoints)
	Duplicate/O SpikeTimes_1,SpikeTimes_2,SpikeTimes_3,SpikeTimes_4

	SetScale/P x 0,1/jSc_stim_sampFreq,"s", jSc_xVw,jSc_yVw,jSc_shutterWave,jSc_blankWave
	SetScale d 0,0,"V", jSc_xVw,jSc_yVw,jSc_shutterWave,jSc_blankWave

	//// Create postsynaptic current injection waves
	NVAR/Z		SpTm_wDur
	Variable testPulseDur = SealTestDur+SealTestPad1+SealTestPad2
	SpTm_wDur = Rightx(jSc_shutterWave)+testPulseDur*1e-3					// Accounting for test pulse duration
	RunSpTm2Waves()															// This creates Out_1_ST through Out_4_ST
	WAVE		Out_1_ST,Out_2_ST,Out_3_ST,Out_4_ST
	Duplicate/O Out_1_ST,Out_1												// Then create Out_1 through Out_4
	Duplicate/O Out_2_ST,Out_2
	Duplicate/O Out_3_ST,Out_3
	Duplicate/O Out_4_ST,Out_4
	Out_1[0,numpnts(jSc_xVw)-1] = 0											// Delete all spike-generating current injections, but keep the test pulse at the end
	Out_2[0,numpnts(jSc_xVw)-1] = 0
	Out_3[0,numpnts(jSc_xVw)-1] = 0
	Out_4[0,numpnts(jSc_xVw)-1] = 0
	if (jSc_VerboseMode)
		print "Automatically generated ePhys waves called:\tOut_1_ST to Out_4_ST, as well as Out_1 to Out_4."
	endif

	//// Modify shutter wave
	Variable nMissingPoints = numpnts(Out_1_ST)-numpnts(jSc_shutterWave)					// Because of test pulse, the e-phys waves are longer than the shutter wave
	InsertPoints numpnts(jSc_shutterWave), nMissingPoints, jSc_shutterWave,jSc_blankWave	// Make sure they're the same length, otherwise e-phys data acquistion will choke
	jSc_shutterWave[numpnts(jSc_shutterWave)-nMissingPoints,numpnts(jSc_shutterWave)-1] = jSc_stim_shutterClosed		// Make sure added points indicate shutter closed
	jSc_blankWave[numpnts(jSc_blankWave)-nMissingPoints,numpnts(jSc_blankWave)-1] = jSc_stim_shutterClosed
	Duplicate/O jSc_shutterWave, Out_shutterWave												// Change wave name to start with Out_ to enable selection in panels that otherwise filter
	Duplicate/O jSc_blankWave, Out_blankWave												// these waves out from popup menus
	if (jSc_VerboseMode)
		print "Automatically generated shutter waves called:\tjSc_shutterWave, jSc_blankWave"
		print "\tCopied the above waves to:\tOut_shutterWave, Out_blankWave"
	endif
	
	//// Update rotation in case scan angle was changed
	NVAR	jSc_scanAngle
	jSc_Rotate(jSc_scanAngle,jSc_xVw,jSc_yVw)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot pseudo-random uncaging spots in the form of a grid of points

Function jSc_MakePseudoUncGraph()

	Variable		ScSc = PanelResolution("")/ScreenResolution
	
	Variable		xPos = 12
	Variable		yPos = 70
	Variable		width = 400
	Variable		height = 400

	NVAR		xSpots = jSc_stim_xSize
	NVAR		ySpots = jSc_stim_ySize

	DoWindow/K	JSc_The_Grid
	Display /W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+Height*ScSc) as "Uncaging grid"
	DoWindow/C	JSc_The_Grid
	AppendImage theGrid
	ModifyImage theGrid ctab= {*,*,YellowHot256,0}
	ModifyGraph width={Plan,1,bottom,left}
	ModifyGraph mirror=3
	ModifyGraph manTick={0,1,0,0}//,manMinor={1,50}
	// lines
	AppendToGraph yGrid vs xGrid
	ModifyGraph rgb(yGrid)=(30000,30000,30000)
	ModifyGraph mode(yGrid)=0
	// numbers
	AppendToGraph yGrid vs xGrid
	ModifyGraph rgb(yGrid#1)=(0,0,65535)
	ModifyGraph mode(yGrid#1)=3,textMarker(yGrid#1)={nGrid,"default",0,0,5,0.00,0.00}
	if ((xSpots>8) %| (ySpots>8))
		ModifyGraph msize(yGrid#1)=3
	else
		ModifyGraph msize(yGrid#1)=6
	endif
	JT_AddCloseButton()
	SetAxis/A left
	
	AutoPositionWindow/E/M=1/R=jUncagePanel JSc_The_Grid

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot uncaging sweep voltages in 2D

Function jSc_MakeUncVoltagesGraph()
	if (Exists("jSc_yVw"))
		DoWindow/K jSc_uncVoltagesGraph
		Display /W=(487,513,1177,951) jSc_yVw vs jSc_xVw as "Uncaging sweep voltages"
		DoWindow/C jSc_uncVoltagesGraph
		ModifyGraph mode=4
		ModifyGraph grid=2
		SetAxis/A/N=1 left
		SetAxis/A/N=1 bottom
		ModifyGraph height={Aspect,1}
		JT_addCloseButton()
		JT_ArrangeGraphs2(";;;jSc_uncVoltagesGraph;",2,3)
	else
		print "You need to create the uncaging pattern first."
	endif
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot uncaging sweep voltages over time, together with shutter values

Function jSc_makeUncVoltagesGraph2()
	if (Exists("jSc_yVw"))
		DoWindow/K jSc_uncVoltagesGraph2
		Display /W=(35,44,988,449) jSc_yVw as "Uncaging & shutter voltages"
		DoWindow/C jSc_uncVoltagesGraph2
		AppendToGraph/L=left2 jSc_xVw
		AppendToGraph/L=left3 jSc_shutterWave,jSc_GateWave
		ModifyGraph rgb(jSc_yVw)=(59136,54784,1280),rgb(jSc_xVw)=(26880,43776,64512),rgb(jSc_shutterWave)=(65280,29952,65280),rgb(jSc_GateWave)=(0,0,0)
		ModifyGraph lblPos=60
		ModifyGraph freePos(left2)=0
		ModifyGraph freePos(left3)=0
		ModifyGraph axisEnab(left)={0,0.35}
		ModifyGraph axisEnab(left2)={0.4,0.75}
		ModifyGraph axisEnab(left3)={0.8,1}
		Label left "y values (\\U)"
		Label left2 "x values (\\U)"
		Label left3 "shutter (\\U)"
		JT_addCloseButton()
		JT_ArrangeGraphs2("jSc_uncVoltagesGraph2;",2,1)
		Legend/A=RB
	else
		print "You need to create the uncaging pattern first."
	endif
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot raster-scan voltages in 2D

Function jSc_makeRasterVoltagesGraph()
	if (Exists("jSc_xRaster"))
		DoWindow/K jSc_rasterVoltagesGraph
		Display /W=(149,44,789,400) jSc_yRaster vs jSc_xRaster as "Raster-scan voltages in 2D"
		DoWindow/C jSc_rasterVoltagesGraph
		ModifyGraph grid=1
		SetAxis/A/N=1 left
		SetAxis/A/N=1 bottom
		ModifyGraph height={Aspect,1}
		JT_addCloseButton()
		JT_ArrangeGraphs2(";;;;jSc_rasterVoltagesGraph;",3,3)
		SetAxis left,-3,3
		SetAxis bottom,-3,3
	else
		print "You need to scan at least once before looking creating this plot."
	endif
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot raster-scan voltages over time

Function jSc_makeRasterVoltagesGraph2()
	if (Exists("jSc_xRaster"))
		DoWindow/K jSc_rasterVoltagesGraph2
		Display /W=(149,44,789,400) jSc_xRaster as "Raster-scan voltages over time"
		DoWindow/C jSc_rasterVoltagesGraph2
		AppendToGraph/R jSc_yRaster
		ModifyGraph mode=0
		ModifyGraph rgb(jSc_yRaster)=(0,0,65535)
		Cursor/P A jSc_xRaster 3983
		JT_addCloseButton()
		JT_ArrangeGraphs2("jSc_rasterVoltagesGraph2;",3,1)
		SetAxis left,-3,3
		SetAxis right,-3,3
	else
		print "You need to scan at least once before looking creating this plot."
	endif
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Manage debug graphs

Function jSc_MakeDebugGraphs()

	jSc_plotArchimedeanSpiral()
	jSc_MakeUncVoltagesGraph()
	jSc_MakeUncVoltagesGraph2()
	jSc_makeRasterVoltagesGraph()
	jSc_makeRasterVoltagesGraph2()
	jSc_MakePseudoUncGraph()

End

Function jSc_CloseDebugGraphs()

	DoWindow/K jSc_uncVoltagesGraph
	DoWindow/K jSc_uncVoltagesGraph2
	DoWindow/K jSc_rasterVoltagesGraph
	DoWindow/K jSc_rasterVoltagesGraph2
//	DoWindow/K JSc_The_Grid
	DoWindow/K ArchiSpiralGraph

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Park laser

Function jSc_parkLaser(xVal,yVal)
	Variable	xVal,yVal
	
	SVAR	jSc_outDevStr
	NVAR	jSc_max_xAmp
	NVAR	jSc_max_yAmp
	
	NVAR	jSc_VerboseMode
	
	if (xVal>jSc_max_xAmp)
		print "xVal="+num2str(xVal)+" is outside the range allowed by jSc_max_xAmp="+num2str(jSc_max_xAmp)+"."
		abort "xVal="+num2str(xVal)+" is outside the range allowed by jSc_max_xAmp="+num2str(jSc_max_xAmp)+"."
	endif
	if (yVal>jSc_max_yAmp)
		print "yVal="+num2str(yVal)+" is outside the range allowed by jSc_max_yAmp="+num2str(jSc_max_yAmp)+"."
		abort "yVal="+num2str(yVal)+" is outside the range allowed by jSc_max_yAmp="+num2str(jSc_max_yAmp)+"."
	endif
#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: jSc_parkLaser simulated"
	endif
#else
	fDAQmx_WriteChan(jSc_outDevStr, 0, xVal, -10, 10)
	fDAQmx_WriteChan(jSc_outDevStr, 1, yVal, -10, 10)
#endif
	
End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Park galvo shutter

Function jSc_parkGalvoShutter(theVal)
	Variable	theVal
	
	SVAR	jSc_outDevStr
	NVAR	jSc_gateOut
	
	NVAR	jSc_VerboseMode
	
#ifdef DemoMode
	if (jSc_VerboseMode)
		print "\t\tDemoMode: jSc_parkGalvoShutter simulated"
	endif
#else
	fDAQmx_WriteChan(jSc_outDevStr, jSc_gateOut, theVal, -10, 10)
	print "Setting galvo shutter to "+num2str(theVal)+" V."
#endif
	
End


