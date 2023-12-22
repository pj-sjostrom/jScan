#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CONNECTIVITY MAPPER
// by Jesper Sjöström, starting on 2021-05-03
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2021-05-06
//	*	A first functional version done
//	*	Loads both images and 2p zap data automatically
//	*	Talks to JT Load Waves to get at the connectivity
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2021-11-17
//	*	Massive update with relatively complete analysis across layers, within column, and radially.
//	*	Added export feature
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2021-11-23
//	*	Added z-coordinate to radial distance metric and to exported files
//	*	Added EPSP amplitude heatmap plot
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2021-11-24
//	*	Added layouts of stats data
//	*	Added 3d scatter plot of connectivity
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2021-12-16
//	*	Analyses and exports each cells layer and column location (CMAP_LayerLoc and CMAP_ColumnLoc)
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2022-01-10
//	*	CMap now understands that the zeroth FOV image may solely serve to indicate the XYZ location of the 
//		postsynaptic cell, so has no responses. Use CMap_lineZeroWasInserted to fix previously analyzed experiments.
//		Just enter 0 (zero) in the first (zeroth) line of 'Suffix start' column in the 'CMap Parameters' table.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2022-01-25
//	*	Added button to Pull EPSP amplitudes for current line/FOV from JT LoadData, similar to how to Pull connectivity.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2022-01-30
//	*	Heat map used gaussian blobs with double the diameter, instead of radius. Also made sure diameter
//		matched gaussian blob half-width rather than gaussian blob sigma; this was a minor correction.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-02-10
//	*	Can now handle direct activation of cells that express opsin.
//	*	Added tag for "trash" inputs, i.e., those that should not count as neither connected nor unconnected.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-02-13
//	*	Export information about direct activation and trash cells
//	*	Fixed bug associated with Push/Pull connectivity for direct activation and trash cells
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-04-08
//	*	The third pulse (if there is one) is now analyzed. JTools was also updated accordingly.
//	*	User can now do layer stats analysis for a chosen pulse number, which is useful for e.g. PC->MC connections.
//	*	The most recently analyzed pulse is also the one that is exported as useAmp value. The data table remembers 
//		which pulse in position 18. -- Be careful before exporting! --
//	*	The raw response values for amp1, 2, and 3 are also exported.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-04-09
//	*	Added a manual override feature, so that the user can fix individual responses that were not correctly
//		calculated by the automatic algorithm. In particular, this can be used to account for direct depolarization.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-04-22
//	*	Now extracts the maximum depolarization as well as the latency (in ms) of that peak depolarization. Since 
//		PC-MC connections have appreciable temporal summation, this may be a more representative way of measuring
//		strength of these connections.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-06-05
//	*	Fixed a bug that erased the manual-override table when re-initing the panel.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-06-07
//	*	EPSP treshold for first amplitude, CMap_RespThres, is now applied as more-than rather than 
//		more-than-or-equal. (The corresponding threshold for PPR, CMap_PPRthres, was already correct.)
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-09-06
//	*	Medial and anterior left vs. right now implemented
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-10-24
//	*	Created separate function call for the linear histogram, CMap_BinHist() .
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-11-06
//	*	Now calculates the shortest cell-cell distance stats.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	TO-DO AND PENDING BUG FIXES
//	*	Lateral connectivity mapping
//	*	PPR is not automatically calculated when Amp1 is too small. Or is manual inspection and override better?
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

menu "Macros"
	"Init Connectivity Mapper",CMap_init()
	"Clear source table",CMap_doClearTable()
	"Connectivity Mapper to front",doWindow/F CMapPanel
	"Show extracted image coordinates",CMap_ShowImageCoordinateData()
	"Show connectivity",CMap_ZapsAndConnectivity()
	"Kill progress bar",JT_KillProgressBar()
	"Toggle symbols in FOV images",CMap_toggleSymbolsInFOVs()
	"Scrap all override values",CMap_ScrapAllOverrideValues()
	"Do shortest cell-cell distance stats",CMap_shortestDistance()
	"-"
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create a shortest-distance histogram

Function CMap_shortestDistance()

	WAVE	CMap_LayoutX
	WAVE	CMap_LayoutY
	WAVE	CMap_LayoutZ = CMap_LayoutStageZ

	Make/O/N=(0) workWave	
	Variable	n = numpnts(CMap_LayoutX)
	Variable	currX,currY,currZ
	Variable	i
	i = 1		// Skip postsynaptic cell
	do
		Duplicate/O CMap_LayoutX,tempX,currR	,indexW	// /R=[1,]
		Duplicate/O CMap_LayoutY,tempY
		Duplicate/O CMap_LayoutZ,tempZ
		currX = CMap_LayoutX[i]
		currY = CMap_LayoutY[i]
		currZ = CMap_LayoutZ[i]
		tempX = CMap_LayoutX-currX		// Center on current presynaptic cell
		tempY = CMap_LayoutY-currY
		tempZ = CMap_LayoutZ-currZ
		currR = sqrt(tempX^2+tempY^2+tempZ^2)
		indexW = p
		Sort currR,currR,indexW
		WaveStats/Q/R=[1,10]	currR
		workWave[numpnts(workWave)] = {median(currR,3,8)} // {V_avg}		Grain-of-salt warning: Try to account for the fact that sometimes the same cell is selected twice
		i += 1
	while(i<n)
	
	doWindow/K Distance_histogram
	JT_MakeHist("workWave",50,"distance (µm)","Distance histogram")
	JT_ArrangeGraphs2("Distance_histogram;",3,3)
	
	WaveStats/Q workWave
	print V_avg,"±",V_SDev,V_SEM,"µm"
	print "Median:",median(workWave),"µm"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Adjust for the fact that line zero was inserted 
//// (Special case when adding image of postsynaptic cell)

Function CMap_lineZeroWasInserted()

	WAVE/T		CMap_imageName
	
	String		sourceStr
	String		destStr

	Variable	n = numpnts(CMap_imageName)
	Variable	i
	i = n-1
	do
		sourceStr = "CMap_responseWave_"+JT_num2digstr(2,i-1)
		destStr = "CMap_responseWave_"+JT_num2digstr(2,i)
		print "Moving from "+sourceStr+" to "+destStr
		Duplicate/O $(sourceStr),$(destStr)
		i -= 1
	while(i>0)
	print "Creating "+sourceStr
	Make/O/N=(0) $(sourceStr)

End
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Manage the stats layouts

Function CMap_makeStatsLayoutsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMap_makeStatsLayouts()
			break
	endswitch

	return 0
End

Function CMap_makeStatsLayouts()

	CMap_killStatsLayouts()
	
	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		xPos = 20*ScSc
	Variable		yPos = 80*ScSc
	Variable		width = 950*ScSc
	Variable		height = 700*ScSc
	Variable		spacing = 64*ScSc
	Variable		i = 0
	
	// Layout 1 -- Connectivity across layers
	NewLayout/W=(xPos*+i*spacing,yPos+i*spacing,xPos+width+i*spacing,yPos+height+i*spacing) as "Connectivity across layers"
	doWindow/C Stats_layout_1
	LayoutPageAction size=(792,612),margins=(18,18,18,18)
	ModifyLayout mag=1
	AppendLayoutObject/F=0/T=1/R=(21,35,265,213) Graph LayerStatsGraph1
	AppendLayoutObject/F=0/T=1/R=(21,221,265,399) Graph LayerStatsGraph2
	AppendLayoutObject/F=0/T=1/R=(273,35,517,213) Graph LayerStatsGraph4
	AppendLayoutObject/F=0/T=1/R=(273,221,517,399) Graph LayerStatsGraph5
	AppendLayoutObject/F=0/T=1/R=(525,221,769,399) Graph LayerStatsGraph7
	AppendLayoutObject/F=0/T=1/R=(525,35,769,213) Graph LayerStatsGraph9
	i += 1
	
	// Layout 2 -- Radial connectivity
	NewLayout/W=(xPos+i*spacing,yPos+i*spacing,xPos+width+i*spacing,yPos+height+i*spacing) as "Radial connectivity"
	doWindow/C Stats_layout_2
	LayoutPageAction size=(792,612),margins=(18,18,18,18)
	ModifyLayout mag=1
	AppendLayoutObject/F=0/T=1/R=(35,25,384,207) Graph LayerStatsGraph3
	AppendLayoutObject/F=0/T=0/R=(35,183,384,365) Graph LayerStatsGraph6
	AppendLayoutObject/F=0/T=0/R=(35,341,384,523) Graph LayerStatsGraph10
	i += 1
	
	// Layout 3 -- Connectivity maps
	NewLayout/W=(xPos+i*spacing,yPos+i*spacing,xPos+width+i*spacing,yPos+height+i*spacing) as "Connectivity maps"
	doWindow/C Stats_layout_3
	LayoutPageAction size=(792,612),margins=(18,18,18,18)
	ModifyLayout mag=1
	AppendLayoutObject/F=0/T=1/R=(25,23,371,339) Graph LayerStatsGraph8
	AppendLayoutObject/F=0/T=1/R=(400,23,704,339) Graph LayerStatsGraph11
	i += 1
	
End

Function CMap_killStatsLayoutsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMap_killStatsLayouts()
			break
	endswitch

	return 0
End

Function CMap_killStatsLayouts()

	doWindow/K Stats_layout_1
	doWindow/K Stats_layout_2
	doWindow/K Stats_layout_3

End

Function CMap_StatsLayoutsToBackProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMap_StatsLayoutsToBack()
			break
	endswitch

	return 0
End

Function CMap_StatsLayoutsToBack()

	doWindow/B Stats_layout_1
	doWindow/B Stats_layout_2
	doWindow/B Stats_layout_3

End

///////////////////////////////////////////////////////////////
//// Init variables

Function CMap_toggleSymbolsInFOVs()

	WAVE/T		CMap_imageName
	SVAR		CMap_GraphList
	WAVE		CMap_imageStart

	Variable	n = numpnts(CMap_imageName)
	Variable	i
	String	currFile
	String	currGraph

	String visibleTraces=TraceNameList("",";",1+4)	// only visible normal traces
	String allNormalTraces=TraceNameList("",";",1)	// hidden + visible normal traces
	String hiddenTraces= RemoveFromList(visibleTraces,allNormalTraces)
	
	Variable	hideTraces = 1

	String wY

	i = 0
	do
		currFile = CMap_imageName[i]
		currGraph = currFile[0,strLen(currFile)-1-4]
		if (i==0)
			visibleTraces = TraceNameList(currGraph,";",1+4)
			allNormalTraces = TraceNameList(currGraph,";",1)
			hiddenTraces = RemoveFromList(visibleTraces,allNormalTraces)
			if (ItemsInList(hiddenTraces)>0)
				hideTraces = 0			// Unhide if already hidden
				print "Showing symbols"
			else
				print "Hiding symbols"
			endif
		endif
		doWindow/F $(currGraph)
		wY = "jSc_pointsY_"+JT_num2digstr(4,CMap_imageStart[i])
		if (hideTraces)
			ModifyGraph hideTrace($wY) = 1
		else
			ModifyGraph hideTrace($wY) = 0
		endif
		i += 1
	while(i<n)

End

///////////////////////////////////////////////////////////////
//// Init variables

Function CMap_init()

	print "--- STARTING UP CMAP ---"
	Print date(),time()
	print "Setting up variables..."
	
	// Set up variables
	JT_GlobalVariable("CMap_GraphList",0,"",1)
	JT_GlobalVariable("CMap_ImagePathStr",0,"<empty path>",1)

	JT_GlobalVariable("CMap_layoutScale",50,"",0)								// Overall scale for the layout (%)
	JT_GlobalVariable("CMap_minX",1,"",0)											// Minimum x coordinate
	JT_GlobalVariable("CMap_maxX",1,"",0)											// Maximum x coordinate
	JT_GlobalVariable("CMap_minY",1,"",0)											// Minimum y coordinate
	JT_GlobalVariable("CMap_maxY",1,"",0)											// Maximum y coordinate

	JT_GlobalVariable("CMap_RAT_Str",0,"",1)										// TIFF tags string for recently loaded file
	JT_GlobalVariable("CMap_currStageX",1,"",0)									// Stage X value for recently loaded file
	JT_GlobalVariable("CMap_currStageY",1,"",0)									// Stage Y value for recently loaded file
	JT_GlobalVariable("CMap_currStageZ",1,"",0)									// Stage Z value for recently loaded file

	JT_GlobalVariable("CMap_cellNumber",1,"",0)									// Cell number
	JT_GlobalVariable("CMap_conditionNumber",1,"",0)								// Condition number
	JT_GlobalVariable("CMap_currLine",0,"",0)										// Operating on current line in table
	JT_GlobalVariable("CMap_exportFileName",0,"<empty>",1)						// Export file name (automatically generated, can be edited)
	JT_GlobalVariable("CMap_expDateStr",0,"<empty>",1)							// Experiment date (automatically generated)

	JT_GlobalVariable("CMap_columnWidth",200,"",0)								// Cortical column width (µm)
	JT_GlobalVariable("CMap_radialStep",50,"",0)									// Radial analysis step size (µm)
	JT_GlobalVariable("CMap_radialEnd",750,"",0)									// Radial analysis end of range (µm)

	JT_GlobalVariable("CMap_symbolRadius",6,"",0)									// Layout symbol size (µm)
	JT_GlobalVariable("nTicksWait",0,"",0)											// Slow down analysis (~1/60th of a sec per "tick")

	JT_GlobalVariable("CMap_PPRthres",0.1,"",0)									// When analyzing the PPR, require at least this response amplitude (mV)
	JT_GlobalVariable("CMap_RespThres",0,"",0)										// When analyzing the first pulse amplitude, require at least this response amplitude (mV)

	JT_GlobalVariable("CMap_HeatmapGamma",0.5,"",0)								// Gamma for the heatmap representation

	JT_GlobalVariable("CMap_radialTau",0.5,"",0)									// Radial decay tau (µm)
	
	JT_GlobalVariable("CMap_mostRecentlyAnalyzedPulseNumber",-1,"",0)		// Set up most recently analyzed pulse number

	Print " "		// JT_GlobalVariable uses printf

	// Set up waves
	print "Setting up waves..."
	if (Exists("CMap_imageName")==0)
		print "\tNulling the table data..."
		CMap_ClearTableData()
	else
		print "\tTable data already exist, using old data..."
	endif
	print "\tClearing image coordinate data..."
	CMap_ClearImageCoordinateData()
	
	Create_CMapPanel()
	Create_CMapTable()
	CMap_doSetupDataTable()
//	CMap_doScrapAllOverrideValues()													// Removed 5 June 2023, because this deletes old settings
	DoWindow/F CMapPanel

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Export data

Function CMap_exportDataProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- EXPORTING DATA ---"
			print date(),time()
			CMap_doExportData()
			break
	endswitch

	return 0

End

Function CMap_doExportData()

	SVAR			CMap_exportFileName

	CMap_doSetupDataTable()			// Update data table first
	
	NVAR			CMap_mostRecentlyAnalyzedPulseNumber
	if (CMap_mostRecentlyAnalyzedPulseNumber!=-1)
		doAlert/T="For your information..." 0,"Just so you are aware, the exported data is for EPSP"+num2str(CMap_mostRecentlyAnalyzedPulseNumber)+". If this is not intentional, redo analysis with the green Layer Stats button, then click Export again."
	endif

	doWindow/F CMapPanel

	WAVE/T 		CMap_DataDescription
	WAVE/T 		CMap_Data

	String		SaveListOriginals = ""
	String		targetNames = ""

	// Boolean: Response or not, -1 for postsynaptic cell at index 0
	SaveListOriginals += "CMap_LayoutResp;"
	targetNames += "Resp;"

	// Direct depolarization and trash inputs
	SaveListOriginals += "CMap_LayoutIsDirect;"				// Boolean
	targetNames += "isDirect;"
	SaveListOriginals += "CMap_LayoutDirectDep;"				// Amount of direct depol in the first couple of ms
	targetNames += "DirectDep;"
	SaveListOriginals += "CMap_LayoutIsTrash;"					// Boolean -- do not count for connectivity
	targetNames += "isTrash;"

	// Cell X & Y coordinates (µm), rotated & centered on postsynaptic cell (in X) and on L1/L2 boundary (in Y)
	SaveListOriginals += "CMap_cellX;"
	targetNames += "cellX;"
	SaveListOriginals += "CMap_cellY;"
	targetNames += "cellY;"
	SaveListOriginals += "CMap_LayoutStageZ;"					// Includes Z-coordinate (23 Nov 2021)
	targetNames += "cellZ;"
	
	// Cell belonging, in column, in layer (added 16 Dec 2021)
	SaveListOriginals += "CMAP_LayerLoc;"
	targetNames += "layerLoc;"
	SaveListOriginals += "CMAP_ColumnLoc;"
	targetNames += "columnLoc;"
	
	// Layer X & Y coordinates (µm), rotated & centered on postsynaptic cell (in X) and on L1/L2 boundary (in Y)
	SaveListOriginals += "CMap_LLplotX;"
	targetNames += "LLX;"
	SaveListOriginals += "CMap_LLplotY;"
	targetNames += "LLY;"
	// The corrected first-response amplitude (V) (i.e., if first response fails, then the second is reported), all non-response amplitudes are set to NaN
	SaveListOriginals += "CMap_LayoutUseAmp;"
	targetNames += "UseAmp;"
	// PPR, filtered for sufficiently large Amp1 amplitudes (all other values are NaN)
	SaveListOriginals += "CMap_LayoutUsePPR;"
	targetNames += "PPR;"

	// TPR (raw, unfiltered) (added 9 Apr 2023)
	SaveListOriginals += "CMap_LayoutTPR;"
	targetNames += "TPR;"

	// The raw amplitudes (added 9 Apr 2023)
	SaveListOriginals += "CMap_LayoutAmp1;"
	targetNames += "Amp1;"
	SaveListOriginals += "CMap_LayoutAmp2;"
	targetNames += "Amp2;"
	SaveListOriginals += "CMap_LayoutAmp3;"
	targetNames += "Amp3;"

	// The max depolarization (added 22 Apr 2023)
	SaveListOriginals += "CMap_LayoutMaxDepol;"
	targetNames += "MaxDepol;"
	SaveListOriginals += "CMap_LayoutMaxDepolLoc;"
	targetNames += "MaxDepolLoc;"

	//// CONNECTIVITY
	// Connectivity over layers
	SaveListOriginals += "wPercConnCount;"
	targetNames += "LPercConn;"
	SaveListOriginals += "wConnCount;"
	targetNames += "LConn;"
	SaveListOriginals += "wCellCount;"
	targetNames += "LCells;"

	// Layer labels
	SaveListOriginals += "wLayerLabel;"
	targetNames += "LLabels;"

	// Connectivity over layers in column
	SaveListOriginals += "wPercColumnConnCount;"
	targetNames += "CLPercConn;"
	SaveListOriginals += "wColumnConnCount;"
	targetNames += "CLConn;"
	SaveListOriginals += "wColumnCellCount;"
	targetNames += "CLCells;"
	
	// Radial connectivity
	SaveListOriginals += "wPercCircleConnCount;"
	targetNames += "RPercConn;"
	SaveListOriginals += "wCircleConnCount;"
	targetNames += "RConn;"
	SaveListOriginals += "wCircleCellCount;"
	targetNames += "RCells;"
	SaveListOriginals += "wCircleLabel;"
	targetNames += "RX;"
	
	//// AMPLITUDES
	// Amplitudes over layers
	SaveListOriginals += "wRespAmpMean;"
	targetNames += "LAmpMean;"
	SaveListOriginals += "wRespAmpSEM;"
	targetNames += "LAmpSEM;"

	// Amplitudes over layers in column
	SaveListOriginals += "wColAmpMean;"
	targetNames += "CLAmpMean;"
	SaveListOriginals += "wColAmpSEM;"
	targetNames += "CLAmpSEM;"
	
	// Radial amplitudes
	SaveListOriginals += "wCircleMean;"
	targetNames += "RAmpMean;"
	SaveListOriginals += "wCircleSEM;"
	targetNames += "RAmpSEM;"
	
	//// PPR
	// Amplitudes over layers
	SaveListOriginals += "wRespPPRMean;"
	targetNames += "LPPRMean;"
	SaveListOriginals += "wRespPPRSEM;"
	targetNames += "LPPRSEM;"

	// Radial amplitudes
	SaveListOriginals += "wCirclePPRMean;"
	targetNames += "RPPRMean;"
	SaveListOriginals += "wCirclePPRSEM;"
	targetNames += "RPPRSEM;"
	
	// Data wave
	SaveListOriginals += "CMap_Data;"
	targetNames += "Data;"
	SaveListOriginals += "CMap_DataDescription;"
	targetNames += "Descr;"

	//	Save wLayerNs,2,3 also?
	
	if (itemsInList(SaveListOriginals)!=itemsInList(targetNames))
		print "Strange error in CMap_doExportData. WaveList lengths do not match."
		Abort "Strange error in CMap_doExportData. WaveList lengths do not match."
	endif
	
	String		SaveListCopies = ""
	Variable		n = ItemsInList(SaveListOriginals)
	String		currSource
	String		currTarget
	
	String		ExpName = CMap_Data[3]+"_"
	
	PathInfo	CMap_ExportPath
	if (V_flag)
		PathInfo/S CMap_ExportPath												// Default to this path if it already exists
	endif
	NewPath/O/Q/M="Where do you wish to export the data?" CMap_ExportPath
	PathInfo CMap_ExportPath
	if (V_flag)
		print "\tThe export path: \""+S_path+"\""
	else
		print "ERROR! Path doesn't appear to exist!"
		Abort "ERROR! Path doesn't appear to exist!"
	endif

	Variable	i
	i = 0
	do
		currSource = StringFromList(i,SaveListOriginals)
		currTarget = StringFromList(i,targetNames)
		KillWaves/Z $(ExpName+currTarget)
		Duplicate/O $currSource,$(ExpName+currTarget)
		SaveListCopies += ExpName+currTarget+";"
		i += 1
	while(i<n)

	Print "Saving: "+SaveListCopies
	Print "as \""+CMap_exportFileName+".itx\""
	
	Save/B/T/O/P=CMap_ExportPath SaveListCopies as CMap_exportFileName+".itx"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Update data table from SetVar

Function UpdateDataTableProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			CMap_doSetupDataTable()
			doWindow/F CMapPanel
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set up the data table

Function CMap_SetupDataTableProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			CMap_doSetupDataTable()
			break
	endswitch

	return 0

End

Function CMap_doSetupDataTable()

	NVAR		CMap_cellNumber
	NVAR		CMap_conditionNumber
	SVAR		CMap_exportFileName
	SVAR		CMap_expDateStr
	NVAR		CMap_columnWidth
	NVAR		CMap_radialStep
	NVAR		CMap_radialEnd
	NVAR		CMap_PPRthres
	NVAR		CMap_RespThres
	
	NVAR		CMap_radialTau
	
	NVAR		CMap_mostRecentlyAnalyzedPulseNumber

	CMap_doGetExportFilename()

	Variable	nEntries = 20
	
	Make/O/T/N=(nEntries) CMap_DataDescription
	Make/O/T/N=(nEntries) CMap_Data
	if (!Exists("CMap_Data"))
		CMap_Data = ""
	endif

	CMap_DataDescription[0] = "Date"
	CMap_Data[0] = CMap_expDateStr
	CMap_DataDescription[1] = "Cell #"
	CMap_Data[1] = num2str(CMap_cellNumber)	
	CMap_DataDescription[2] = "Condition #"
	CMap_Data[2] = num2str(CMap_conditionNumber)	
	CMap_DataDescription[3] = "Export file name"
	CMap_Data[3] = CMap_exportFileName
	CMap_DataDescription[4] = "Animal age"
	CMap_DataDescription[5] = "Eyes open"
	CMap_DataDescription[6] = "Weight"
	CMap_DataDescription[7] = "Sex"
	CMap_DataDescription[8] = "Medial/anterior left or right"
	CMap_updateMedialLeftRight()
	CMap_DataDescription[9] = "Other 1"
	CMap_DataDescription[10] = "Other 2"
	CMap_DataDescription[11] = "Other 3"
	CMap_DataDescription[12] = "Column width (µm)"
	CMap_Data[12] = num2str(CMap_columnWidth)
	CMap_DataDescription[13] = "Radial step (µm)"
	CMap_Data[13] = num2str(CMap_radialStep)
	CMap_DataDescription[14] = "Radial max (µm)"
	CMap_Data[14] = num2str(CMap_radialEnd)
	CMap_DataDescription[15] = "EPSP thres for PPR (mV)"
	CMap_Data[15] = num2str(CMap_PPRthres)
	CMap_DataDescription[16] = "EPSP thres for 1st amp (mV)"
	CMap_Data[16] = num2str(CMap_RespThres)
	CMap_DataDescription[17] = "Radial tau (µm)"
	CMap_Data[17] = num2str(CMap_radialTau)
	CMap_DataDescription[18] = "Which pulse"
	CMap_Data[18] = num2str(CMap_mostRecentlyAnalyzedPulseNumber)
	
	DoWindow/K CMap_DataTable
	Edit/K=1/W=(5,53,337+40+60,519) CMap_DataDescription,CMap_Data as "CMap Data Table"
	DoWindow/C CMap_DataTable
	ModifyTable width(CMap_DataDescription)=160,title(CMap_DataDescription)="Description"
	ModifyTable width(CMap_Data)=180,title(CMap_Data)="Value"
	
	AutoPositionWindow/M=0/R=CMapPanel CMap_DataTable

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Update whether medial side is on the left or on the right

Function CMap_updateMedialLeftRight()

	WAVE/T		CMap_Data
	
	ControlInfo/W=CMapPanel medialLeftRightPopup
	CMap_Data[8] = S_Value

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// For each image, how many zaps and how many connections

Function CMap_ZapsAndConnectivity()

	WAVE/T	CMap_imageName
	
	if (numpnts(CMap_imageName)==0)
		Abort "Your parameter table is empty. Load some data first!"
	endif
	
	if (Exists("CMap_n2pZapPoints")==0)
		Abort "Too soon! You need to load your data first!"
	endif
	
	WAVE		CMap_n2pZapPoints
	
	Duplicate/O CMap_n2pZapPoints,CMap_nConnections,CMap_Connectivity
	CMap_Connectivity = NaN
	
	print "--- NUMBER OF ZAP POINTS AND NUMBER OF CONNECTIONS ---"
	print date(),time()

	Variable	n = numpnts(CMap_imageName)
	Variable	i
	Variable currResp
	i = 0
	do
		currResp = -1
		if (Exists("CMap_responseWave_"+JT_num2digstr(2,i)))
			WAVE wResp = $("CMap_responseWave_"+JT_num2digstr(2,i))
			currResp = sum(wResp)
		endif
		CMap_nConnections[i] = currResp
		if (currResp>-1)
			CMap_Connectivity[i] = currResp/CMap_n2pZapPoints[i]*100
		endif
		print "\t\t"+CMap_imageName[i]+", number of zaps: "+num2str(CMap_n2pZapPoints[i])+", number of connections: "+num2str(currResp)+", connectivity: "+num2str(CMap_Connectivity[i])+"%."
		i += 1
	while(i<n)

	Variable		ScSc = PanelResolution("")/ScreenResolution

	WAVE/T	CMap_imageName

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 500
	Variable		Height = 300
	
	DoWindow/K CMapConnectivityTable
	Edit/K=1/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Connectivity for each image"
	DoWindow/C CMapConnectivityTable
	AppendToTable CMap_imageName
	AppendToTable CMap_n2pZapPoints
	AppendToTable CMap_nConnections
	AppendToTable CMap_Connectivity
	
	ModifyTable title(CMap_imageName)="Image name",title(CMap_n2pZapPoints)="nZaps"
	ModifyTable title(CMap_nConnections)="nConnections",title(CMap_Connectivity)="Conn (%)"
	
	ModifyTable width(CMap_imageName)=160

	AutoPositionWindow/M=0/R=CMapPanel CMapConnectivityTable

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Show image coordinate data

Function CMap_ShowImageCoordinateData()

	Variable		ScSc = PanelResolution("")/ScreenResolution

	WAVE/T	CMap_imageName
	WAVE		CMap_useStageX
	WAVE		CMap_useStageY
	WAVE		CMap_useStageZ

	if (numpnts(CMap_imageName)==0)
		Abort "Your parameter table is empty. Load some data first!"
	endif
	
	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 500
	Variable		Height = 300
	
	DoWindow/K CMapImageCoordinatesTable
	Edit/K=1/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Extracted image coordinates"
	DoWindow/C CMapImageCoordinatesTable
	AppendToTable CMap_imageName
	AppendToTable CMap_useStageX
	AppendToTable CMap_useStageY
	AppendToTable CMap_useStageZ
	
	ModifyTable title(CMap_imageName)="Image name",title(CMap_useStageX)="Stage X"
	ModifyTable title(CMap_useStageY)="Stage Y",title(CMap_useStageZ)="Stage Z"
	
	ModifyTable width(CMap_imageName)=160

	AutoPositionWindow/M=0/R=CMapTable CMapImageCoordinatesTable

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Clear image coordinate data

Function CMap_ClearImageCoordinateData()

	WAVE		CMap_tableStageX
	WAVE		CMap_tableStageY
	WAVE		CMap_tableStageZ

//	WAVE		CMap_useStageX
//	WAVE		CMap_useStageY
//	WAVE		CMap_useStageZ

	Duplicate/O CMap_tableStageX,CMap_useStageX
	Duplicate/O CMap_tableStageY,CMap_useStageY
	Duplicate/O CMap_tableStageZ,CMap_useStageZ

	CMap_useStageX = 0
	CMap_useStageY = 0
	CMap_useStageZ = 0

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Clear data in user-entry table

Function CMap_ClearTableData()

	Make/O/T/N=(0)	CMap_imageName
	Make/O/N=(0)	CMap_tableStageX
	Make/O/N=(0)	CMap_tableStageY
	Make/O/N=(0)	CMap_tableStageZ
	Make/O/N=(0)	CMap_PixelsPerMicron
	Make/O/N=(0)	CMap_imageStart
	Make/O/N=(0)	CMap_imageEnd
	Make/O/N=(0)	CMap_ephysStart
	Make/O/N=(0)	CMap_ephysEnd

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the Connectivity Map Panel

Function Create_CMapPanel()
	
	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 560
	Variable		Ypos = 64
	Variable		Width = 480
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow CMapPanel
	if (V_flag)
		GetWindow CMapPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
		print "Using old panel coordinates:",xPos,yPos
		
		ControlInfo/W=CMapPanel overrideCheck
		if (V_flag==2)
			Variable/G	CMap_overrideCheckVal = V_value
			print "Using old checkbox value",V_value
		else
			Variable/G	CMap_overrideCheckVal = 0
		endif
		
	else
		Variable/G	CMap_overrideCheckVal = 0
	endif

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12

	DoWindow/K CMapPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Connectivity Map"
	DoWindow/C CMapPanel
	ModifyPanel/W=CMappanel fixedSize=1
	
	Button SetPathButton,pos={xMargin,y},size={120,bHeight},proc=CMap_SetImagePathProc,title="Set the image path",fsize=fontSize,font="Arial"
	SetVariable PathStrSetVar,frame=0,noedit=1,pos={xMargin+120+4,y+3},size={Width-xMargin*2-120-4,bHeight},title=" ",value=CMap_ImagePathStr,limits={0,0,0},fsize=fontSize,font="Arial"
	y += ySkip
	
	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button LoadAllButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_LoadAllDataProc,title="Load all",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	Button makeLayoutButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_makeLayoutProc,title="Make layout",fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable ScaleSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Scale (%)",value=CMap_layoutScale,limits={5,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable cellNumberSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Cell #",proc=UpdateDataTableProc,value=CMap_cellNumber,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable conditionNumberSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Condition #",proc=UpdateDataTableProc,value=CMap_conditionNumber,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable currLineSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Acting on table line",proc=CMap_currLineSVproc,value=CMap_currLine,limits={0,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	Button PushToJTloadWavesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_PushToJTloadWavesProc,title="Load+Zoom table line w JT Load Waves",fsize=fontSize,font="Arial"
	x += xSkip
	Button PullConnFromJTloadWavesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_PullConnFromJTloadWavesProc,title="Pull connectivity from JT Load Waves",fsize=fontSize,font="Arial",fColor=(65535,0,0)
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	Button PushBackConnectivityButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_PushBackConnectivityProc,title="Push connectivity data to JT Load Waves",fsize=fontSize,font="Arial",fColor=(0,0,65535)
	x += xSkip
	Button PullEPSPsFromJTloadWavesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_PullEPSPsFromJTloadWavesProc,title="Pull EPSPs from JT Load Waves",fsize=fontSize,font="Arial",fColor=(65535,0,0)
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	Button analyzeAllImagesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_analyzeAllSynapticResponsesProc,title="Reanalyze all images (slow)",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	Button Zap2LayoutButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_Zap2LayoutProc,title="2p Zap -> layout",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/4)
	x = xMargin
	Button ReplotImagesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_replotImagesProc,title="Replot images",fsize=fontSize,font="Arial"
	x += xSkip
	Button KillImagesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_killImagesProc,title="Kill images",fsize=fontSize,font="Arial"
	x += xSkip
	Button imagesToFrontButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_imagesToFrontProc,title="Images to front",fsize=fontSize,font="Arial"
	x += xSkip
	Button imagesToBackButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_imagesToBackProc,title="Images to back",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button PickLayerLinesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_getLayoutLinesProc,title="Store layer lines",fsize=fontSize,font="Arial"
	x += xSkip
	Button RedrawLayerLinesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_addLinesBackToLayoutProc,title="Redraw layer lines",fsize=fontSize,font="Arial"
	x += xSkip
	Button KillLayerLinesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_killLayoutLinesProc,title="Delete layer lines",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable columnWidthSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Column width (µm)",proc=UpdateDataTableProc,value=CMap_columnWidth,limits={50,Inf,10},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable nTicksWaitSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Slow down analysis (ticks)",value=nTicksWait,limits={0,Inf,10},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable symbolRadiusSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Symbol radius (µm)",value=CMap_symbolRadius,limits={1,Inf,1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable radialStepSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Radial step (µm)",proc=UpdateDataTableProc,value=CMap_radialStep,limits={5,Inf,5},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable radialEndSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Radial max (µm)",proc=UpdateDataTableProc,value=CMap_radialEnd,limits={100,Inf,50},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button LayerStatsButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_LayerStatsProc,title="Layer stats",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	PopupMenu LayerStatsOnWhichPopup,pos={x,y+2},size={xSkip-4,bHeight},proc=CMap_LayerStatsPopupProc,title="on specific EPSP",mode=0,value="EPSP 1;EPSP 2;EPSP 3;Max Depol;",fsize=fontSize,font="Arial"
	x += xSkip
	Button redrawLayerStatsGraphsButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_redrawLayerStatsGraphsProc,title="Redraw layer stats graphs",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/4)
	x = xMargin
	CheckBox overrideCheck,pos={x,y+4},size={xSkip-4,bHeight},title="Manual override",value=CMap_overrideCheckVal,fsize=fontSize,font="Arial"
	x += xSkip
	Button editOverrideValuesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_editOverrideValuesProc,title="Edit overrides",fsize=fontSize,font="Arial"
	x += xSkip
	Button autoSetSomeOverrideValuesButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_autoSetSomeOverrideValuesProc,title="Auto PPR & TPR",fsize=fontSize,font="Arial"
	x += xSkip
	Variable/G	CMap_nManualOverrides = 0
	SetVariable nOverridesDisplay,pos={x,y+2},size={xSkip-4,bHeight},title="# overrides",value=CMap_nManualOverrides,disable=2,frame=1,limits={-Inf,Inf,0},fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable PPRthresSetVar,pos={x,y+3},size={2*xSkip-4,bHeight},title="EPSP threshold for PPR analysis (mV)",proc=UpdateDataTableProc,value=CMap_PPRthres,limits={0,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	x += xSkip
	PopupMenu PlotModePopup,pos={x,y+2},size={xSkip-4,bHeight},title="Plot mode",value="Bar graphs;Box plots;Violin plots;",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SetVariable respThresSetVar,pos={x,y+3},size={2*xSkip-4,bHeight},title="EPSP threshold for 1st amp (mV)",proc=UpdateDataTableProc,value=CMap_RespThres,limits={0,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	x += xSkip
	SetVariable GammaSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Gamma",proc=CMap_updateGammaProc,value=CMap_HeatmapGamma,limits={0,Inf,0.1},fsize=fontSize,font="Arial"
	y += ySkip

	xSkip = floor((Width-xMargin*2)/4)
	x = xMargin
	SetVariable exportFilenameSetVar,frame=1,pos={x,y+3},size={3*xSkip-4,bHeight},title="Export as",value=CMap_exportFileName,limits={0,0,0},fsize=fontSize,font="Arial"
	x += xSkip
	x += xSkip
	x += xSkip
	Button updateExportFilenameButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_getExportFilenameProc,title="Update name",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	PopupMenu medialLeftRightPopup,pos={x,y+2},size={xSkip-4,bHeight},proc=medialLeftRightPopMenuProc,title="Medial/anterior left or right?",value="Left;Right;",fsize=fontSize,font="Arial"
	x += xSkip
	Button exportDataButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_exportDataProc,title="Export",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/4)
	x = xMargin
	Button makeLayoutsButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_makeStatsLayoutsProc,title="Make layouts",fsize=fontSize,font="Arial"
	x += xSkip
	Button killLayoutsButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_killStatsLayoutsProc,title="Kill layouts",fsize=fontSize,font="Arial"
	x += xSkip
	Button LayoutsToBackButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_StatsLayoutsTobackProc,title="Layouts to back",fsize=fontSize,font="Arial"
	x += xSkip
	Button makeScatter3dButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_makeScatter3dProc,title="3D scatter",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button RedrawPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_RedrawPanelProc,title="Redraw panel",fsize=fontSize,font="Arial"
	x += xSkip
	Button ReInitButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_ReInitProc,title="Re-init",fsize=fontSize,font="Arial"
	x += xSkip
	Button DataTableButton,pos={x,y},size={xSkip-4,bHeight},proc=CMap_SetupDataTableProc,title="Show data table",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	MoveWindow/W=CMapPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Read out medial left/right popup

Function medialLeftRightPopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			CMap_updateMedialLeftRight()
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Ensure current line is not out of bounds

Function CMap_currLineSVproc(sva) : SetVariableControl
	STRUCT	WMSetVariableAction &sva
	
	NVAR		CMap_currLine
	WAVE/T		CMap_imageName

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			if (CMap_currLine>numpnts(CMap_imageName)-1)
				CMap_currLine = numpnts(CMap_imageName)-1
				print "Table line selection outside bounds."
			endif
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Convert each FOV image's XY points to the coordinate
//// system of the layout
//// NB! The zeroth point denotes the position of the recorded cell!

Function CMap_Zap2LayoutProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- CONVERTING 2P ZAP XY TO LAYOUT XY ---"
			print date(),time()
			doWindow CMap_Layout
			if (V_flag==0)		// Create layout if it does not exist
				CMap_makeImageLayout()
			endif
			CMap_ZapXYtoLayoutXY()
			break
	endswitch

	return 0

End

Function CMap_ZapXYtoLayoutXY()

	WAVE/T		CMap_imageName
	WAVE		CMap_imageStart
	
	WAVE		imX = CMap_useStageX
	WAVE		imY = CMap_useStageY
	WAVE		imZ = CMap_useStageZ
	WAVE		CMap_PixelsPerMicron

	NVAR		CMap_layoutScale							// Layout scale
	Variable	sc = CMap_layoutScale/100
	Variable	imSc											// Image scale (pixels/µm) for current image

	Variable	xMargin = 20
	Variable	yMargin = 20
	Variable	imWidth = 512*sc
	Variable	imHeight = 512*sc

	NVAR		minX = CMap_minX
	NVAR		maxX = CMap_maxX
	NVAR		minY = CMap_minY
	NVAR		maxY = CMap_maxY

	Variable	i,j,k
	Variable	xx,yy
	Variable	nImages
	Variable	nPoints
	
	Variable	isBelow
	Variable	isAbove

	// Find center of zeroth FOV imange; this is where the recorded cell is	
	Make/O/N=(1) CMap_LayoutX,CMap_LayoutY,CMap_LayoutStageZ,CMap_LayoutResp,CMap_LayoutMarkers,CMap_LayoutIsDirect,CMap_LayoutDirectDep,CMap_LayoutIsTrash
	imSc = CMap_PixelsPerMicron[0]
	CMap_LayoutX[0] = xMargin-minX*sc+imX[0]*sc + imWidth/imSc / 2			// Source is in XY stage coordinates (µm), converted to layout coordinates
	CMap_LayoutY[0] = yMargin-minY*sc+imY[0]*sc + imHeight/imSc / 2
	CMap_LayoutStageZ[0] = imZ[0]											// This was set to zero until 2022-01-10
	CMap_LayoutResp[0] = -1													// WARNING! Zeroth data point is the recorded cell! So zapped cells start at index 1 and zeroth response is -1 (red circle)
	CMap_LayoutMarkers[0] = 60												// Markers
 	CMap_DrawLayoutXYsymbol(CMap_LayoutX[0],CMap_LayoutY[0],CMap_LayoutResp[0])
	
	nImages = numpnts(CMap_imageName)
	j = 0
	do		// Go through FOV images
		WAVE wX = $("jSc_pointsX_"+JT_num2digstr(4,CMap_imageStart[j]))
		WAVE wY = $("jSc_pointsY_"+JT_num2digstr(4,CMap_imageStart[j]))
		WAVE responseWave = $("CMap_responseWave_"+JT_num2digstr(2,j))
		WAVE isDirectWave = $("CMap_isDirectWave_"+JT_num2digstr(2,j))
		WAVE directDepWave = $("CMap_directDepWave_"+JT_num2digstr(2,j))
		WAVE isTrashWave = $("CMap_isTrashWave_"+JT_num2digstr(2,j))

		nPoints = numpnts(responseWave)		// NB! responseWave may have fewer points than wX/wY
		imSc = CMap_PixelsPerMicron[j]
		k = 0
		if (numpnts(wX)>0)							// NB! wX/wY may have zero data points for image indicating postsynaptic cell
			do		// Go through zap points in image
				xx = xMargin-minX*sc+imX[j]*sc+wX[k]/imSc*sc
				yy = yMargin-minY*sc+imY[j]*sc+wY[k]/imSc*sc
				CMap_LayoutX[numpnts(CMap_LayoutX)] = {xx}
				CMap_LayoutY[numpnts(CMap_LayoutY)] = {yy}
				CMap_LayoutStageZ[numpnts(CMap_LayoutStageZ)] = {imZ[j]}
				CMap_LayoutResp[numpnts(CMap_LayoutResp)] = {responseWave[k]}
				CMap_LayoutMarkers[numpnts(CMap_LayoutMarkers)] = {responseWave[k] ? 19 : 8}
				CMap_LayoutIsDirect[numpnts(CMap_LayoutIsDirect)] = {isDirectWave[k]}
				CMap_LayoutDirectDep[numpnts(CMap_LayoutDirectDep)] = {directDepWave[k]}
				CMap_LayoutIsTrash[numpnts(CMap_LayoutIsTrash)] = {isTrashWave[k]}
				CMap_DrawLayoutXYsymbol(xx,yy,responseWave[k])
				k += 1
			while(k<nPoints)
		endif
		j += 1
	while(j<nImages)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Draw a single symbol in layout XY coordinate space

Function CMap_DrawLayoutXYsymbol(xx,yy,resp)
	Variable	xx,yy,resp
	
	NVAR		CMap_symbolRadius
	NVAR		CMap_layoutScale		// Layout scale (% µm)
	
	Variable	r = CMap_symbolRadius*CMap_layoutScale/100
	
	doWindow/F CMap_layout
	SetDrawLayer UserFront
	switch(resp)
		case 0:		// Unconnected cell
			SetDrawEnv linefgc=(33536,40448,47872),fillfgc=(33536,40448,47872),fillpat=0
			break
		case 1:		// Connected cell
			SetDrawEnv linefgc=(33536,40448,47872),fillfgc=(33536,40448,47872),fillpat=1
			break
		case -1:		// Recorded cell
			SetDrawEnv linefgc=(0,0,0),fillfgc=(65535,0,0),fillpat=1
			break
		case -2:		// Special draw mode when temporarily shown
			SetDrawEnv linefgc=(0,0,0),fillfgc=(33536,40448,47872),fillpat=1,lineThick=2
			break
	endswitch
	DrawOval xx-r,yy-r,xx+r,yy+r

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get the y-axis crossing point (the offset) of a line

Function CMap_getLineOffset(x1,y1,x2,y2)
	Variable	x1,y1,x2,y2			// line
	
	Variable	offset = y1-CMap_getLineSlope(x1,y1,x2,y2)*x1
	
	Return		offset

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get the slope of a line

Function CMap_getLineSlope(x1,y1,x2,y2)
	Variable	x1,y1,x2,y2			// line
	
	Variable	slope = (y2-y1)/(x2-x1)
	
	Return		slope

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Is this coordinate above the line?
//// NB! Origin (0,0) is in the top left corner

Function CMap_AboveLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0				// point to be tested
	Variable	x1,y1,x2,y2			// line

	Variable	above
	
	above = (y0 - y1)*(x2-x1) - (x0 - x1)*(y2- y1)
	
	above *= sign(x2-x1)
	
	above = above < 0
	
	Return		above

end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Is this coordinate below the line?
//// NB! Origin (0,0) is in the top left corner

Function CMap_BelowLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0				// point to be tested
	Variable	x1,y1,x2,y2			// line

	Return		(!(CMap_AboveLine(x0,y0,x1,y1,x2,y2)))

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Is this coordinate to the right of the line?
//// NB! Origin (0,0) is in the top left corner

Function CMap_RightOfLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0				// point to be tested
	Variable	x1,y1,x2,y2			// line

	// Swap x and y around
	Return		(CMap_BelowLine(y0,x0,y1,x1,y2,x2))

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Is this coordinate to the left of the line?
//// NB! Origin (0,0) is in the top left corner

Function CMap_LeftOfLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0				// point to be tested
	Variable	x1,y1,x2,y2			// line

	// Swap x and y around
	Return		(CMap_AboveLine(y0,x0,y1,x1,y2,x2))

End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Calculate the distance between a coordinate and a line

Function CMap_DistToLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0,x1,y1,x2,y2

//	http://mathworld.wolfram.com/Point-LineDistance2-Dimensional.html
//	
//	line is given by (x1,y1) to (x2,y2)
//	point is given by (x0,y0)
//	
//	d = abs((x2-x1)*(y1-y0)-(x1-x0)*(y2-y1))/sqrt((x2-x1)^2+(y2-y1)^2)

	Variable	d = abs((x2-x1)*(y1-y0)-(x1-x0)*(y2-y1))/sqrt((x2-x1)^2+(y2-y1)^2)

	Return		d

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Kill images

Function CMap_killImagesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	SVAR		CMap_GraphList

	switch( ba.eventCode )
		case 2: // mouse up
			JT_ArrangeGraphs5(CMap_GraphList)
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move images to front

Function CMap_imagesToFrontProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	SVAR		CMap_GraphList

	switch( ba.eventCode )
		case 2: // mouse up
			JT_ArrangeGraphs3(CMap_GraphList)
			DoWindow/F CMap_layout
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Move images to back

Function CMap_imagesToBackProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	SVAR		CMap_GraphList

	switch( ba.eventCode )
		case 2: // mouse up
			JT_ArrangeGraphs6(CMap_GraphList)
			DoWindow/B CMap_layout
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Replot images. Especially useful once the connectivity data has been loaded.

Function CMap_replotImagesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMap_doPlotAll()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Push back previously stored connectivity to JT Load Waves

Function CMap_PushBackConnectivityProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMap_doPushBackConnectivity()
			break
	endswitch

	return 0
End

Function CMap_doPushBackConnectivity()

	NVAR		CMap_currLine
	
	Print "--- PUSHING CONNECTIVITY ---"

	Variable	connectedFlag
	Variable	directFlag
	Variable	trashFlag
	Variable	buttonMode
	Variable	channelNumber = 2
	WAVE/Z		JT_LD_responseWave = $("JT_LD_responseWave"+num2str(channelNumber))			// NB! Hard-wired for operating on Channel 2!
	WAVE/Z		JT_LD_isDirectWave = $("JT_LD_isDirectWave"+num2str(channelNumber))
	if (exists("JT_LD_isDirectWave"+num2str(channelNumber))==0)
		Duplicate/O JT_LD_responseWave,$("JT_LD_isDirectWave"+num2str(channelNumber))		// Ensure backwards compatiblity of experiments that did not analyze for direct activation
		JT_LD_isDirectWave = 0
	endif
	WAVE/Z		JT_LD_isTrashWave = $("JT_LD_isTrashWave"+num2str(channelNumber))
	if (exists("JT_LD_isTrashWave"+num2str(channelNumber))==0)
		Duplicate/O JT_LD_responseWave,$("JT_LD_isTrashWave"+num2str(channelNumber))
		JT_LD_isTrashWave = 0
	endif
	
	// RECALL
	WAVE		storedResponses = $("CMap_responseWave_"+JT_num2digstr(2,CMap_currLine))
	Duplicate/O storedResponses,JT_LD_responseWave					// NB! These are two wave references, not two wave names!

	if (exists("CMap_isDirectWave_"+JT_num2digstr(2,CMap_currLine))==0)			// Ensure backwards compatiblity
		Duplicate/O $("CMap_responseWave_"+JT_num2digstr(2,CMap_currLine)),$("CMap_isDirectWave_"+JT_num2digstr(2,CMap_currLine))
		WAVE		storedDirectActivations = $("CMap_isDirectWave_"+JT_num2digstr(2,CMap_currLine))
		storedDirectActivations = 0
	endif
	WAVE		storedDirectActivations = $("CMap_isDirectWave_"+JT_num2digstr(2,CMap_currLine))
	Duplicate/O storedDirectActivations,JT_LD_isDirectWave			// NB! These are two wave references, not two wave names!

	if (exists("CMap_isTrashWave_"+JT_num2digstr(2,CMap_currLine))==0)			// Ensure backwards compatiblity
		Duplicate/O $("CMap_responseWave_"+JT_num2digstr(2,CMap_currLine)),$("CMap_isTrashWave_"+JT_num2digstr(2,CMap_currLine))
		WAVE		storedTrashes = $("CMap_isTrashWave_"+JT_num2digstr(2,CMap_currLine))
		storedTrashes = 0
	endif
	WAVE		storedTrashes = $("CMap_isTrashWave_"+JT_num2digstr(2,CMap_currLine))
	Duplicate/O storedTrashes,JT_LD_isTrashWave						// NB! These are two wave references, not two wave names!

	Variable	n = numpnts(JT_LD_responseWave)
	Variable	i
	i = 0
	do
		doWindow/F $("JT_LD_ZoomGr_"+num2str(channelNumber)+"_"+num2str(i))
		if (V_flag==0)
			Abort "Could not find zoom graph number "+num2str(i)+". Try reloading."
		endif
		connectedFlag = JT_LD_responseWave[i]
		directFlag = JT_LD_isDirectWave[i]
		trashFlag = JT_LD_isTrashWave[i]
		buttonMode = connectedFlag*2^0 + directFlag*2^1
		if (trashFlag)
			buttonMode = 2^2		// If trash, override the other two flags
		endif
		JT_LD_setButton("hasResponseButton"+num2str(channelNumber)+JT_num2digstr(4,i),buttonMode)
//		CheckBox $("hasResponseCheck")+num2str(channelNumber)+JT_num2digstr(4,i) value=JT_LD_responseWave[i],win=$("JT_LD_ZoomGr_"+num2str(channelNumber)+"_"+num2str(i))	// Old way of selecting
		JT_LD_DrawBars(i,JT_LD_responseWave[i],JT_LD_isDirectWave[i],JT_LD_isTrashWave[i])
		i += 1
	while(i<n)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pull synaptic responses data JTools Load Waves panel

Function CMap_PullEPSPsFromJTloadWavesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- PULLING SYNAPTIC RESPONSE DATA FROM JT LOAD WAVES ---"
			print date(),time()
			CMap_doPullEPSPsFromJTloadWaves()
			break
	endswitch

	return 0
End

Function CMap_doPullEPSPsFromJTloadWaves()
	NVAR		CMap_currLine

	CMap_storeAwaySynapticResponseData(2,CMap_currLine,0)	// Store away the synaptic stats for this table line (hardwired to channel 2)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Pull connectivity data JTools Load Waves panel

Function CMap_PullConnFromJTloadWavesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- PULLING CONNECTIVITY DATA FROM JT LOAD WAVES ---"
			print date(),time()
			CMap_doPullConnFromJTloadWaves()
			break
	endswitch

	return 0
End

Function CMap_doPullConnFromJTloadWaves()

	WAVE/T	CMap_imageName

	WAVE		CMap_ephysStart
	WAVE		CMap_ephysEnd
	
	WAVE		CMap_imageStart
	WAVE		CMap_imageEnd

	NVAR		CMap_cellNumber
	NVAR		CMap_currLine
	
	Variable	channelNumber = 2
	WAVE/Z		JT_LD_responseWave = $("JT_LD_responseWave"+num2str(channelNumber))			// NB! Hard-wired for loading from Channel 2!
	if (Exists("JT_LD_responseWave"+num2str(channelNumber))==0)
		Abort "Cannot pull data from JT Load Waves, because responses have not been defined on channel "+num2str(channelNumber)+"."
	else
		print "--- PULLING CONNECTIVITY DATA ---"
		print "from channel "+num2str(channelNumber)+" of JT Load Waves for table line "+num2str(CMap_currLine)+" and image name \""+CMap_imageName[CMap_currLine]+"\"."
		print date(), time()
	endif

	// To ensure backwards compatiblity of experiments that did not analyze for direct activation, first create non-existent waves and set them to zero
	WAVE/Z		JT_LD_isDirectWave = $("JT_LD_isDirectWave"+num2str(channelNumber))
	if (exists("JT_LD_isDirectWave"+num2str(channelNumber))==0)
		Duplicate/O JT_LD_responseWave,$("JT_LD_isDirectWave"+num2str(channelNumber))
		JT_LD_isDirectWave = 0
	endif
	WAVE/Z		JT_LD_isTrashWave = $("JT_LD_isTrashWave"+num2str(channelNumber))
	if (exists("JT_LD_isTrashWave"+num2str(channelNumber))==0)
		Duplicate/O JT_LD_responseWave,$("JT_LD_isTrashWave"+num2str(channelNumber))
		JT_LD_isTrashWave = 0
	endif

	String	wY = "jSc_pointsY_"+JT_num2digstr(4,CMap_imageStart[CMap_currLine])

	if (Exists(wY)==1)
		WAVE	w = $wY
		if ( (numpnts(w)-1 != numpnts(JT_LD_responseWave)) %& (numpnts(w) != numpnts(JT_LD_responseWave)) )
			Print "Warning! A mismatch was found:"
			print "\t\tJT Load Data reported "+num2str(numpnts(JT_LD_responseWave))+" data points."
			print "\t\tBut "+num2str(numpnts(w))+" data points were stored with the file \""+CMap_imageName[CMap_currLine]+"\"."
			doAlert 0,"Warning! There is a mismatch in the number of data points reported from JT Load Waves compared to the number of zap coordinates found associated with this image file."
		endif
	else
		Print "Warning! No 2p zap data points were found associated with the file \""+CMap_imageName[CMap_currLine]+"\"."
		Print "Did you not yet click the 'Load all' button?"
		doAlert 0,"Warning! No 2p zap data points were found."
	endif
	
	if (Exists(wY)==1)
		WAVE	w = $wY
		if (numpnts(w) == numpnts(JT_LD_responseWave))
			Print "Data was found and the n's are matching."
			print "\t\tThere are "+num2str(numpnts(JT_LD_responseWave))+" data points, with "+num2str(sum(JT_LD_responseWave))+" connected."
		endif
	endif
	
	String	currResponses = "CMap_responseWave_"+JT_num2digstr(2,CMap_currLine)
	String	currDirectResponses = "CMap_isDirectWave_"+JT_num2digstr(2,CMap_currLine)
	String	currTrashResponses = "CMap_isTrashWave_"+JT_num2digstr(2,CMap_currLine)
	String	currMarkers = "CMap_markerWave_"+JT_num2digstr(2,CMap_currLine)
	Duplicate/O JT_LD_responseWave,$(currResponses)
	Duplicate/O JT_LD_isDirectWave,$(currDirectResponses)
	Duplicate/O JT_LD_isTrashWave,$(currTrashResponses)
	CMap_responsesToMarkers(currResponses,currMarkers,currDirectResponses,currTrashResponses)
	print "\t\tStoring this data as \""+currResponses+"\", \""+currDirectResponses+"\", and \""+currTrashResponses+"\", ."

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Push data from table out to JTools Load Waves panel, creating it if it does not already exists

Function CMap_PushToJTloadWavesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- PUSHING DATA TO JT LOAD WAVES ---"
			print date(),time()
			CMap_doPushToJTloadWaves(1)
			JT_LoadDataProc("CMap_remoteControl")		// Call button control with special ctrlName
			break
	endswitch

	return 0
End

Function CMap_doPushToJTloadWaves(showMessages)
	Variable	showMessages

	WAVE		CMap_ephysStart
	WAVE		CMap_ephysEnd
	
	NVAR		CMap_cellNumber
	NVAR		CMap_currLine
	
	if (CMap_currLine+1>numpnts(CMap_ephysStart))
		Abort "'Line' larger than the number of values in the CMap Parameters table."
	endif

	// Create the Load Waves panel if it does not already exist	
	DoWindow JT_LoadWavesPanel
	if (V_flag==0)
		JT_MakeLoadWavesPanel()
	endif
	
	// Load only from Channel 1
	WAVE		JT_LoadDataFromThisChannel
	JT_LoadDataFromThisChannel = {0,1,0,0}
	CheckBox LoadFrom1Check value=0, win=JT_LoadWavesPanel 
	CheckBox LoadFrom2Check value=1, win=JT_LoadWavesPanel 
	CheckBox LoadFrom3Check value=0, win=JT_LoadWavesPanel 
	CheckBox LoadFrom4Check value=0, win=JT_LoadWavesPanel 
//	JT_ToggleLoadFromProc("LoadFrom2Check",1)
	
	SVAR		JT_WaveNamesIn2
	JT_WaveNamesIn2 = "Cell_"+JT_num2digstr(2,CMap_cellNumber)+"_"
	
	NVAR		JTLoadData_Suff2Start
	JTLoadData_Suff2Start = CMap_ephysStart[CMap_currLine]
	
	NVAR		JT_nRepsToLoad
	JT_nRepsToLoad = CMap_ephysEnd[CMap_currLine]-CMap_ephysStart[CMap_currLine]+1
	
	if (Exists("CMap_n2pZapPoints"))
		WAVE		CMap_n2pZapPoints
		NVAR		JT_LD_nResponses				// Number of responses to display
		JT_LD_nResponses = CMap_n2pZapPoints[CMap_currLine]
		if (showMessages)
			print "\tYou should go through "+num2str(CMap_n2pZapPoints[CMap_currLine])+" zooms."
		endif
	endif
	
	if (showMessages)
		Print "\t\tNow 'Load & Zoom' the ephys data from channel 2 and determine which inputs have connections."	
		doWindow/F JT_LoadWavesPanel
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make a layout of all images

Function CMap_makeLayoutProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- MAKE LAYOUT OF ALL IMAGES ---"
			print date(),time()
			CMap_makeImageLayout()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Load all the data

Function CMap_LoadAllDataProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- LOADING ALL DATA ---"
			print date(),time()
			CMap_doLoadAllimages()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Load all the image files

Function CMap_doLoadAllimages()

	WAVE/T	CMap_imageName
	WAVE		CMap_tableStageX
	WAVE		CMap_tableStageY
	WAVE		CMap_tableStageZ
	WAVE		CMap_PixelsPerMicron
	WAVE		CMap_imageStart
	WAVE		CMap_imageEnd
	WAVE		CMap_ephysStart
	WAVE		CMap_ephysEnd

	WAVE		CMap_useStageX
	WAVE		CMap_useStageY
	WAVE		CMap_useStageZ

	NVAR		CMap_currStageX
	NVAR		CMap_currStageY
	NVAR		CMap_currStageZ
	
	NVAR		CMap_minX
	NVAR		CMap_maxX
	NVAR		CMap_minY
	NVAR		CMap_maxY

	CMap_minX = Inf
	CMap_maxX = -Inf
	CMap_minY = Inf
	CMap_maxY = -Inf

	CMap_ClearImageCoordinateData()
	
	Duplicate/O CMap_tableStageX,CMap_n2pZapPoints
	CMap_n2pZapPoints = 0

	Variable	n = numpnts(CMap_imageName)
	Variable	i
	i = 0
	do
		CMap_load(i)
		if ( (CMap_tableStageX[i]==-1) %& (CMap_tableStageY[i]==-1) %& (CMap_tableStageZ[i]==-1) )
			// -1 entry in table means read coordinates from tiff header
			CMap_useStageX[i] = CMap_currStageX
			CMap_useStageY[i] = CMap_currStageY
			CMap_useStageZ[i] = CMap_currStageZ
		else
			// Otherwise read coordinates from table
			CMap_useStageX[i] = CMap_tableStageX[i]
			CMap_useStageY[i] = CMap_tableStageY[i]
			CMap_useStageZ[i] = CMap_tableStageZ[i]
		endif
		// Find smallest and largest coordinates
		if (CMap_useStageX[i]<CMap_minX)
			CMap_minX = CMap_useStageX[i]
		endif
		if (CMap_useStageX[i]>CMap_maxX)
			CMap_maxX = CMap_useStageX[i]
		endif
		if (CMap_useStageY[i]<CMap_minY)
			CMap_minY = CMap_useStageY[i]
		endif
		if (CMap_useStageY[i]>CMap_maxY)
			CMap_maxY = CMap_useStageY[i]
		endif
		i += 1
	while(i<n)
	
	print "\tX coordinates range from "+num2str(CMap_minX)+" to "+num2str(CMap_maxX)+"."
	print "\tY coordinates range from "+num2str(CMap_minY)+" to "+num2str(CMap_maxY)+"."
	
	CMap_doPlotAll()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make layout of all images

Function CMap_makeImageLayout()

	WAVE/T	CMap_imageName
	
	WAVE		imX = CMap_useStageX
	WAVE		imY = CMap_useStageY
	WAVE		imZ = CMap_useStageZ
	WAVE		CMap_PixelsPerMicron
	
	NVAR		CMap_layoutScale							// Layout scale
	Variable sc = CMap_layoutScale/100
	Variable imSc											// Image scale (pixels/µm) for current image

	Variable	xMargin = 20
	Variable yMargin = 20
	Variable imWidth = 512*sc
	Variable imHeight = 512*sc
	
	Variable layoutWidth = 612
	Variable layoutHeight = 792

	NVAR		minX = CMap_minX
	NVAR		maxX = CMap_maxX
	NVAR		minY = CMap_minY
	NVAR		maxY = CMap_maxY

	doWindow/K CMap_layout
	NewLayout/B=(0,0,0)/K=0/N=CMap_layout/P=Portrait/W=(65,95,1200,1000) as "Connectivity Map"
	ModifyLayout mag = 1.7
	if (IgorVersion() >= 7.00)
		LayoutPageAction size=(layoutWidth,layoutHeight),margins=(18,18,18,18)
	endif
	AutoPositionWindow/M=1/R=CMapPanel CMap_layout

	Variable	n = numpnts(CMap_imageName)
	Variable	i
	String	currFile
	i = 0
	do
		currFile = CMap_imageName[i]
		imSc = CMap_PixelsPerMicron[i]
		AppendLayoutObject/F=0/R=(xMargin-minX*sc+imX[i]*sc,yMargin-minY*sc+imY[i]*sc,xMargin-minX*sc+imX[i]*sc+imWidth/imSc,yMargin-minY*sc+imY[i]*sc+imHeight/imSc) graph $(currFile[0,strLen(currFile)-1-4])
		i += 1
	while(i<n)

	SetDrawLayer UserFront
	SetDrawEnv linefgc= (65535,65535,65535),save
	SetDrawEnv linethick= 2,linefgc= (65535,65535,65535),fillpat= 0
	variable xScBar = xMargin	// Scale bar position X (layout coordinates)
	variable yScBar = yMargin	// Scale bar position Y (layout coordinates)
	variable	lenScBar = 100		// Scale bar length (µm)
	DrawPoly xScBar,yScBar,1,1,{xScBar, yScBar, xScBar + lenScBar*sc, yScBar}
	SetDrawEnv textxjust= 1,textyjust= 2,fname= "Arial",fstyle= 1, textrgb= (65535,65535,65535)
	DrawText xScBar + lenScBar*sc/2, yScBar, num2str(lenScBar)+" µm"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot all the images

Function CMap_doPlotAll()

	WAVE/T	CMap_imageName
	SVAR		CMap_GraphList
	JT_ArrangeGraphs5(CMap_GraphList)			// Kill graphs first

	Print "--- PLOTTING ALL IMAGES ---"

	Variable	n = numpnts(CMap_imageName)
	Variable	i
	String	currFile
	i = 0
	CMap_GraphList = ""
	do
		CMap_plotImage(i)
		currFile = CMap_imageName[i]
		CMap_GraphList += currFile[0,strLen(currFile)-1-4]+";"
		i += 1
	while(i<n)
	
	JT_ArrangeGraphs(CMap_GraphList)

End

///////////////////////////////////////////////////////////////
//// Plot one image

Function CMap_plotImage(fileNumber)
	Variable fileNumber

	WAVE/T		CMap_imageName
	WAVE		CMap_imageStart
	WAVE		CMap_imageEnd

	NVAR		CMap_currStageX
	NVAR		CMap_currStageY
	NVAR		CMap_currStageZ
	SVAR		CMap_RAT_Str

	Variable		Xpos = 64
	Variable		Ypos = 64
	Variable		Width = 420
	Variable		Height = 420

	String	currFile = CMap_imageName[fileNumber]
	
	print "\t\t"+currFile[0,strLen(currFile)-1-4]
	doWindow/K $(currFile[0,strLen(currFile)-1-4])
	Display/W=(Xpos,Ypos,Xpos+Width,Ypos+Height) as "Line "+num2str(fileNumber)+": "+currFile
	doWindow/C $(currFile[0,strLen(currFile)-1-4])
	AppendImage/T $(currFile)
	ModifyImage $(currFile) ctab= {*,128,YellowHot,0}
	ModifyGraph margin(left)=-1,margin(bottom)=-1,margin(top)=-1,margin(right)=-1
	ModifyGraph mirror=0
	ModifyGraph nticks=0
	ModifyGraph noLabel=2
	ModifyGraph standoff=0
	ModifyGraph axThick=0
	SetAxis/A/R left

	// Add markers
	String wY = "jSc_pointsY_"+JT_num2digstr(4,CMap_imageStart[fileNumber])
	String wX = "jSc_pointsX_"+JT_num2digstr(4,CMap_imageStart[fileNumber])
	AppendToGraph/L/T $wY vs $wX
	ModifyGraph RGB($wY)=(131*256,158*256,187*256)
	ModifyGraph mode($wY)=3
	ModifyGraph marker($wY)=0
	ModifyGraph mrkThick($wY)=1

	// Modify markers according to connectivity, if known
	String	currResponses = "CMap_responseWave_"+JT_num2digstr(2,fileNumber)
	String	currDirectResponses = "CMap_isDirectWave_"+JT_num2digstr(2,fileNumber)
	String	currTrashResponses = "CMap_isTrashWave_"+JT_num2digstr(2,fileNumber)
	String	currMarkers = "CMap_markerWave_"+JT_num2digstr(2,fileNumber)
	if (Exists(currResponses))
		print "\t\t\t\tFound connectivity information, modifying markers accordingly."
		CMap_responsesToMarkers(currResponses,currMarkers,currDirectResponses,currTrashResponses)
		ModifyGraph zmrkNum($wY)={$currMarkers}
	endif

End

Function CMap_responsesToMarkers(responses,markers,directResponses,trashResponses)
	string	responses,markers,directResponses,trashResponses

	Duplicate/O $responses,$markers
	WAVE	wResp = $responses
	WAVE	wMark = $markers
	wMark = wResp[p] ? 19 : 1										// Closed circle if connected, cross otherwise
	
	if (Exists(directResponses))
		WAVE	wDirect = $directResponses
		wMark = wResp[p] %& wDirect[p] ? 16 : wMark[p]		// Closed square if both connected and directly activated
		wMark = (!wResp[p]) %& wDirect[p] ? 12 : wMark[p]	// Open square with a cross, if NOT connected BUT directly activated
	endif

	if (Exists(trashResponses))
		WAVE	wTrash = $trashResponses
		wMark = wTrash[p] ? 20 : wMark[p]							// Forward-slash if response is trash
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Clear the source data table

Function CMap_ClearTableProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMap_doClearTable()
			break
	endswitch

	return 0
End

Function CMap_doClearTable()

	DoAlert/T="Sanity check!" 1,"Are you sure you want to clear the table?"
	if (V_flag==1)
		Print "--- CLEARING TABLE ---"
		Print date(),time()
		CMap_ClearTableData()
		CMap_ClearImageCoordinateData()
	else
		Print "Table was not cleared..."
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Reinit

Function CMap_ReInitProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- REINITIATING CMAP ---"
			Print "Note that any checkbox values are reset..."
			CMap_init()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Redraw panel

Function CMap_RedrawPanelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Create_CMapPanel()
			Create_CMapTable()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the Connectivity Map Panel

Function Create_CMapTable()

	Variable		ScSc = PanelResolution("")/ScreenResolution

	WAVE/T		CMap_imageName
	WAVE		CMap_tableStageX
	WAVE		CMap_tableStageY
	WAVE		CMap_tableStageZ
	WAVE		CMap_PixelsPerMicron
	WAVE		CMap_imageStart
	WAVE		CMap_imageEnd
	WAVE		CMap_ephysStart
	WAVE		CMap_ephysEnd

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 900
	Variable		Height = 200
	
	DoWindow/K CMapTable
	Edit/K=1/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "CMap Parameters"
	DoWindow/C CMapTable
	AppendToTable CMap_imageName
	AppendToTable CMap_tableStageX
	AppendToTable CMap_tableStageY
	AppendToTable CMap_tableStageZ
	AppendToTable CMap_PixelsPerMicron
	AppendToTable CMap_imageStart
	AppendToTable CMap_imageEnd
	AppendToTable CMap_ephysStart
	AppendToTable CMap_ephysEnd
	
	ModifyTable title(CMap_imageName)="Image name",title(CMap_tableStageX)="Stage X"
	ModifyTable title(CMap_tableStageY)="Stage Y",title(CMap_tableStageZ)="Stage Z"
	ModifyTable title(CMap_PixelsPerMicron)="Pixels/µm",title(CMap_imageStart)="Suffix start"
	ModifyTable title(CMap_imageEnd)="Suffix end",title(CMap_ephysStart)="Ephys start"
	ModifyTable title(CMap_ephysEnd)="Ephys end"
	
	ModifyTable width(CMap_imageName)=160

	AutoPositionWindow/M=1/R=CMapPanel CMapTable

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set the path string

Function CMap_SetImagePathProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			 CMap_DoSetImagePath()
			break
	endswitch

	return 0
End

Function CMap_DoSetImagePath()

	SVAR			CMap_ImagePathStr
	String		dummyStr

	PathInfo CMap_imagePath
	if (V_flag)
		PathInfo/S CMap_imagePath												// Default to this path if it already exists
	endif
	NewPath/O/Q/M="Chose the path to the image files!" CMap_imagePath
	PathInfo CMap_imagePath
	if (V_flag)
		print "--- SETTING THE SOURCE IMAGE PATH ---"
		print Date(),Time()
		CMap_ImagePathStr = S_path[0,15]+" ... "+S_path[strlen(S_path)-32,strlen(S_path)-1]
		print "\t\t\""+S_path+"\""
		CMap_doGetExportFilename()
	else
		print "ERROR! Path doesn't appear to exist!"
		CMap_ImagePathStr = "<nul>"
	endif
	
End

///////////////////////////////////////////////////////////////
//// Get experiment file name

Function CMap_getExportFilenameProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			 CMap_doGetExportFilename()
			break
	endswitch

	return 0
End

Function CMap_doGetExportFilename()

	SVAR			CMap_ImagePathStr
	NVAR			CMap_cellNumber
	NVAR			CMap_conditionNumber
	SVAR			CMap_exportFileName
	
	SVAR			CMap_expDateStr
	
	CMap_doGetExperimentDate()
	
	CMap_exportFileName = "CMap_"+CMap_expDateStr+"_"+JT_num2digstr(2,CMap_cellNumber)+"_"+JT_num2digstr(1,CMap_conditionNumber)

End

///////////////////////////////////////////////////////////////
//// Get experiment date

Function CMap_doGetExperimentDate()

	SVAR			CMap_expDateStr
	SVAR			CMap_ImagePathStr

	CMap_expDateStr = CMap_ImagePathStr[strlen(CMap_ImagePathStr)-2-7,strlen(CMap_ImagePathStr)-2]

End

///////////////////////////////////////////////////////////////
//// Load image file
//// Note that fileNumber starts at zero!

Function CMap_load(fileNumber)
	Variable fileNumber

	WAVE/T	CMap_imageName
	WAVE		CMap_imageStart
	WAVE		CMap_imageEnd
	
	WAVE		CMap_n2pZapPoints

	NVAR		CMap_currStageX
	NVAR		CMap_currStageY
	NVAR		CMap_currStageZ
	SVAR		CMap_RAT_Str

	String	currFile = CMap_imageName[fileNumber]
	
	PathInfo CMap_imagePath
	if (!(V_flag))
		Abort "The image path has not been set!"
	endif

	KillDataFolder/Z root:Tag0											// Avoid having these data folders build up as more images are loaded
	KillDataFolder/Z root:Tag1
	ImageLoad/Q/P=CMap_imagePath/T=tiff/O/S=1/C=1/BIGT=1/LTMD currFile
	WAVE/T	T_Tags = root:Tag0:T_Tags
	CMap_RAT_Str = T_Tags[CMap_FindIMAGEDESCRIPTION(T_Tags)]
	String/G $("CMap_RAT_Str_"+JT_num2digstr(2,fileNumber))/N=store_RAT_Str
	store_RAT_Str = CMap_RAT_Str
	print "\t\t"+currFile,"\tdate:"+StringByKey("date",CMap_RAT_Str,"=","\r"),"\ttime:"+StringByKey("time",CMap_RAT_Str,"=","\r"), "\tx,y,z:\t"+StringByKey("stgX",CMap_RAT_Str,"=","\r")+",\t"+StringByKey("stgY",CMap_RAT_Str,"=","\r")+",\t"+StringByKey("stgZ",CMap_RAT_Str,"=","\r")
	CMap_currStageX = str2num(StringByKey("stgX",CMap_RAT_Str,"=","\r"))
	CMap_currStageY = str2num(StringByKey("stgY",CMap_RAT_Str,"=","\r"))
	CMap_currStageZ = str2num(StringByKey("stgZ",CMap_RAT_Str,"=","\r"))
	KillDataFolder/Z root:Tag0
	KillDataFolder/Z root:Tag1
	
	if (CMap_imageStart[fileNumber]>0)
		LoadWave/Q/H/P=CMap_imagePath/O "jSc_pointsX_"+JT_num2digstr(4,CMap_imageStart[fileNumber])+".ibw"
		if (V_flag==0)
			Abort "The suffix number "+num2str(CMap_imageStart[fileNumber])+" appears not to exist (see line "+num2str(fileNumber)+" in the parameter table)."
		else
			WAVE	w = $("jSc_pointsX_"+JT_num2digstr(4,CMap_imageStart[fileNumber]))
			print "\t\t\t\tNumber of 2p zap points found: ",numpnts(w)
			print "\t\t\t\tAssuming that the last point is not used, so the effective number of points is: ",numpnts(w)-1
			CMap_n2pZapPoints[fileNumber] = numpnts(w)-1
		endif
		LoadWave/Q/H/P=CMap_imagePath/O "jSc_pointsY_"+JT_num2digstr(4,CMap_imageStart[fileNumber])+".ibw"
		LoadWave/Q/H/P=CMap_imagePath/O "jSc_pointsN_"+JT_num2digstr(4,CMap_imageStart[fileNumber])+".ibw"
	else
		Make/O/N=(0) jSc_pointsX_0000,jSc_pointsY_0000,jSc_pointsN_0000
		Make/O/N=(0) CMap_responseWave_00,CMap_isDirectWave_00,CMap_directDepWave_00,CMap_isTrashWave_00		// Kludge if user does not Pull connectivity from image on line zero that has no zaps
	endif

End

///////////////////////////////////////////////////////////////
////	Find IMAGEDESCRIPTION tag from jScan

Function CMap_FindIMAGEDESCRIPTION(theWave)
	WAVE/T	theWave

	Variable	theIndex = -1
	
	Variable	i = 0
	Variable	nRows = DimSize(theWave,0)
	
	String	currStr
	
	do
		currStr = theWave[i]
		if (StringMatch("IMAGEDESCRIPTION",currStr[0,15]))
			theIndex = i
			i = Inf
		endif
		i += 1
	while (i<nRows)

	Return	theIndex
	
end

/////////////////////////////////////////////////////////////////////////////////////////////////////////
////	Analyze all synaptic responses for all images in CMap Parameters table

Function CMap_analyzeAllSynapticResponsesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			DoAlert/T="This is slow!" 1,"Are you sure you want to do this?"
			if (V_flag==1)
				print "=== Reanalyzing all synaptic responses ==="
				print date(),time()
				CMap_doAnalyzeAllSynapticResponses()
			else
				print "Okay, not now..."
			endif
			break
	endswitch

	return 0
End

Function CMap_doAnalyzeAllSynapticResponses()

	WAVE/T		CMap_imageName
	WAVE		CMap_imageStart
	
	NVAR		CMap_currLine
	
	Variable	store_CMap_currLine = CMap_currLine

	JT_MakeProgressBar(0,"Analyzing...")

	Variable	n = numpnts(CMap_imageName)
	Variable	i
	i = 0
	do
		CMap_currLine = i
		Print "--- Working on table line "+num2str(CMap_currLine)+", which is file \""+CMap_imageName[i]+"\". ---"
		JT_UpdateProgressBar(i/(n-1),"Analyzing image "+num2str(CMap_currLine+1)+"/"+num2str(n)+": \""+CMap_imageName[i]+"\"")
		if (CMap_imageStart[CMap_currLine]>0)			// If no stim was done, then this image just indicates the location of the postsynaptic cell
			CMap_doPushToJTloadWaves(0)						// Push load settings
			JT_LoadDataProc("CMap_remoteControl")		// Call button control with special ctrlName
			doUpdate
			CMap_doPushBackConnectivity()					// Push stored connectivity data
			JT_LoadData_doStats(2,-1,0)						// Do stats on all responses for the current table line (hardwired to channel 2; no response highlight; show no table)
			CMap_storeAwaySynapticResponseData(2,i,0)	// Store away the synaptic stats for this table line (hardwired to channel 2)
			JT_LoadData_doClose()								// Close all the little zoom-in graphs!
		else
			CMap_storeAwaySynapticResponseData(2,i,1)	// If no stim was done, fake up the waves to have nil information
		endif
		i += 1
	while(i<n)
	
//	CMap_combineAllStoredAwaySynapticResponseData()	// Should this really be done here? Shouldn't it be done at start of Layer Stats call?

	// Reset back tothe orignal table line
	CMap_currLine = store_CMap_currLine
	CMap_doPushToJTloadWaves(0)							// Push stored settings
	
	JT_KillProgressBar()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
////	Store away synaptic response data for the current figure
////	into slots as defined by the CMap line number

Function CMap_storeAwaySynapticResponseData(channelNumber,lineNumber,doFake)
	Variable	channelNumber,lineNumber,doFake

	Print "\tStoring away synaptic response data for channel "+num2str(channelNumber)+" and table line number "+num2str(lineNumber)+"."
	String	prefix1 = "JT_LD_"
	String	prefix2 = "CMap_"
	String	suffix1 = num2str(channelNumber)
	String	suffix2 = "_"+JT_num2digstr(2,lineNumber)
	String	waveList = ""
	waveList += "responseWave;"
	waveList += "responseAmp1Wave;"
	waveList += "responseAmp2Wave;"
	waveList += "responseAmp3Wave;"
	waveList += "responseCV1Wave;"
	waveList += "responseCV2Wave;"
	waveList += "responseCV3Wave;"
	waveList += "responsePPRWave;"
	waveList += "responseTPRWave;"
	
	waveList += "maxDepolWave;"
	waveList += "maxDepolLocWave;"
	
	waveList += "isDirectWave;"
	waveList += "directDepWave;"
	waveList += "isTrashWave;"
	String	currStr = ""

	Variable	n = itemsInList(waveList)
	Variable	i
	i = 0
	do
		currStr = stringFromList(i,waveList)
		if (doFake)
			Make/O/N=(0) $(prefix2+currStr+suffix2)
			print "\t\Faking:\t"+prefix2+currStr+suffix2								// This is for the 0th image, in which the postsynaptic cell is centered (no stim was done, so must create empty waves)
		else
			Duplicate/O $(prefix1+currStr+suffix1),$(prefix2+currStr+suffix2)
			print "\t\tCopying:\t"+prefix1+currStr+suffix1+"    -->    "+prefix2+currStr+suffix2
		endif
		i += 1
	while(i<n)
		
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
////	Combined all stored away synaptic response data into one big table
////	that is compatible with CMap_LayoutX,CMap_LayoutY,CMap_LayoutResp

Function CMap_combineAllStoredAwaySynapticResponseData()

	print "\tCombining all data..."

	Make/O/N=(1) CMap_LayoutAmp1,CMap_LayoutAmp2,CMap_LayoutAmp3,CMap_LayoutCV1,CMap_LayoutCV2,CMap_LayoutCV3,CMap_LayoutPPR,CMap_LayoutTPR		// NOTE! Index 0 is reserved for the postsynaptic cell!
	Make/O/N=(1) CMap_LayoutMaxDepol,CMap_LayoutMaxDepolLoc		// NOTE! Index 0 is reserved for the postsynaptic cell!
	Make/O/N=(1) CMap_LineSource,CMAP_LayerLoc,CMAP_ColumnLoc		// NOTE! Index 0 is reserved for the postsynaptic cell!
	
	Variable/G	CMap_nManualOverrides = 0

	String	prefix
	String	suffix

	WAVE/T		CMap_imageName
	Variable	nLines = numpnts(CMap_imageName)
	Variable	nPoints
	Variable	i,j
	Variable	currVal
	i = 0
	do
		prefix = "CMap_"
		suffix = "_"+JT_num2digstr(2,i)
		WAVE		w1 = $(prefix+"responseWave"+suffix)
		nPoints = numpnts(w1)
		WAVE		w2 = $(prefix+"responseAmp1Wave"+suffix)
		WAVE		w3 = $(prefix+"responseAmp2Wave"+suffix)
		WAVE		w4 = $(prefix+"responseCV1Wave"+suffix)
		WAVE		w5 = $(prefix+"responseCV2Wave"+suffix)
		WAVE		w6 = $(prefix+"responsePPRWave"+suffix)
		WAVE		w7 = $(prefix+"responseAmp3Wave"+suffix)
		WAVE		w8 = $(prefix+"responseCV3Wave"+suffix)
		WAVE		w9 = $(prefix+"responseTPRWave"+suffix)
		WAVE		w10 = $(prefix+"maxDepolWave"+suffix)
		WAVE		w11 = $(prefix+"maxDepolLocWave"+suffix)
		print "\t\tLine "+num2str(i)+":",nPoints
		if (nPoints>0)
			j = 0
			do
				currVal = CMap_autoOrOverride(w2[j],i,j,"amp1")
				CMap_LayoutAmp1[numpnts(CMap_LayoutAmp1)] = {currVal}
				currVal = CMap_autoOrOverride(w3[j],i,j,"amp2")
				CMap_LayoutAmp2[numpnts(CMap_LayoutAmp2)] = {currVal}
				currVal = CMap_autoOrOverride(w7[j],i,j,"amp3")
				CMap_LayoutAmp3[numpnts(CMap_LayoutAmp3)] = {currVal}
				currVal = CMap_autoOrOverride(w4[j],i,j,"CV1")
				CMap_LayoutCV1[numpnts(CMap_LayoutCV1)] = {currVal}
				currVal = CMap_autoOrOverride(w5[j],i,j,"CV2")
				CMap_LayoutCV2[numpnts(CMap_LayoutCV2)] = {currVal}
				currVal = CMap_autoOrOverride(w8[j],i,j,"CV3")
				CMap_LayoutCV3[numpnts(CMap_LayoutCV3)] = {currVal}
				currVal = CMap_autoOrOverride(w6[j],i,j,"PPR")
				CMap_LayoutPPR[numpnts(CMap_LayoutPPR)] = {currVal}
				currVal = CMap_autoOrOverride(w9[j],i,j,"TPR")
				CMap_LayoutTPR[numpnts(CMap_LayoutTPR)] = {currVal}

				currVal = CMap_autoOrOverride(w10[j],i,j,"maxDepol")
				CMap_LayoutMaxDepol[numpnts(CMap_LayoutMaxDepol)] = {currVal}
				currVal = CMap_autoOrOverride(w11[j],i,j,"maxDepolLoc")
				CMap_LayoutMaxDepolLoc[numpnts(CMap_LayoutMaxDepolLoc)] = {currVal}

				CMap_LineSource[numpnts(CMap_LineSource)] = {i}			// This is useful for figuring out from which image a response came from

				j += 1
			while (j<nPoints)
		endif
		i += 1
	while(i<nLines)
	
	Duplicate/O CMap_LineSource,CMAP_LayerLoc,CMAP_ColumnLoc
	CMAP_LayerLoc = -1					// Layers are numbered starting at zero, so -1 means layer was not assigned (i.e., a bug)
	CMAP_ColumnLoc = -1				// True means data point is in column, zero means outside column so -1 means column ID was not assigned (i.e., a bug)
	CMAP_ColumnLoc[0] = 1				// ... although postsynaptic cell is by definition always in the column!

	if (Exists("CMap_LayoutX")==0)
		CMap_makeImageLayout()
		CMap_ZapXYtoLayoutXY()
	endif
	WAVE	CMap_LayoutX
	print "\tChecksum:",numpnts(CMap_LayoutX),numpnts(CMap_LayoutAmp1)
	print "\t\tNumber of manual overrides:",CMap_nManualOverrides,"(counting each column in manual override table)"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
////	If manual override checkbox is checked AND if found, return manual override value
////	Otherwise return automatically detected value

Function CMap_autoOrOverride(defaultVal,line,resp,whichStr)
	Variable	defaultVal,line,resp
	String	whichStr

	WAVE	CMap_OR_line
	WAVE	CMap_OR_resp

	//	NB! Fatal error if whichStr does not correctly map onto existing CMap_OR_xxx waves
	// Allowed sources: CMap_OR_amp1, CMap_OR_amp2, CMap_OR_amp3, CMap_OR_CV1, CMap_OR_CV2, CMap_OR_CV3, CMap_OR_PPR, CMap_OR_TPR, CMap_OR_maxDepol, CMap_OR_maxDepolLoc

	NVAR	CMap_nManualOverrides		// Count the number of manual overrides, as a checksum

	Variable	returnVal = defaultVal
	
	Variable	overrideFlag = 0

	ControlInfo/W=CMapPanel overrideCheck
	if (V_flag==2)		// If checkbox exists, use checkbox value
		overrideFlag = V_value
	endif

	if (overrideFlag)
		Variable	nOverrides = numpnts(CMap_OR_line)
		Variable	i
		i = 0
		do
			if (CMap_OR_line[i]==line)
				if (CMap_OR_resp[i]==resp)
					WAVE wSource = $("CMap_OR_"+whichStr)
					if (JT_isNaN(wSource[i])==0)					// Make sure it is not a NaN
						returnVal = wSource[i]
						if (strsearch(whichStr,"amp",0,2)==0)
							returnVal *= 1e-3							// If column is amplitude, remember to convert back from mV to V! (BUG WARNING!)
						endif
						if (stringMatch(whichStr,"maxDepol"))
							returnVal *= 1e-3							// Same for max depolarization (ALSO BUG WARNING!)
						endif
						CMap_nManualOverrides += 1
						print "\t\t\tOverride "+num2str(CMap_nManualOverrides)+" for line "+num2str(line)+", response "+num2str(resp)+", for "+whichStr+", from old value "+num2str(defaultVal)+", to new value "+num2str(returnVal)
						i = Inf
					endif
				endif
			endif
			i += 1
		while(i<nOverrides)
	endif
	
	Return	returnVal

End




/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get the layer boundary lines from the CMap_layout

Function CMap_getLayoutLinesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			print "--- GET LAYER BOUNDARY LINES FROM LAYOUT ---"
			CMap_getLayoutLines()
			break
	endswitch

	return 0

End

Function CMap_getLayoutLines()

	String		recreationStr
	
	doWindow CMap_layout	
	if (V_flag)
		recreationStr = WinRecreation("CMap_layout",0)
	else
		print "The \"CMap_layout\" window does not exist."
		Abort "The \"CMap_layout\" window does not exist."
	endif
	
	Variable	xSearch = 0
	Variable	xFound = -1
	
	String		lineCountBoundaries = ""
	
	print "Searching for lines in the Connectivity Map layout."
	
	Variable	lineCount = 0
	do
		xFound = strsearch(recreationStr,"DrawLine",xSearch,2)
		if (xFound != -1)
			print "\t\tFound a line..."
			lineCount += 1
			lineCountBoundaries += num2str(xFound)+";"
			xSearch = xFound + strLen("DrawLine")
		else
			print "\t\tNo more lines to be found..."
		endif
	while(xFound!=-1)

	Print "Found "+num2str(lineCount)+" lines in total."
	
	if (lineCount==0)
		Print "Found no lines in the layout!"
		Abort "Found no lines in the layout!"
	endif
	
	
	Variable	i
	Variable	x1
	Variable	y1
	Variable	x2
	Variable	y2
	Variable	lowerBound
	Variable	upperBound
	String		currStr
	Make/O/N=(lineCount) x1Wave,y1Wave,x2Wave,y2Wave,lineOffsetWave,lineSlopeWave
	Print "These are the lines:"
	i = 0
	do
		lowerBound = str2num(StringFromList(i,lineCountBoundaries))+strLen("DrawLine ")
		upperBound = strsearch(recreationStr,"\r",lowerBound,2)
		currStr = recreationStr[lowerBound,upperBound]
		x1 = str2num(StringFromList(0,currStr,","))
		y1 = str2num(StringFromList(1,currStr,","))
		x2 = str2num(StringFromList(2,currStr,","))
		y2 = str2num(StringFromList(3,currStr,","))
		print "\t\tLine "+num2str(i+1)+": ("+num2str(Round(x1))+","+num2str(Round(y1))+") to ("+num2str(Round(x2))+","+num2str(Round(y2))+")"
		x1Wave[i] = x1
		y1Wave[i] = y1
		x2Wave[i] = x2
		y2Wave[i] = y2
		lineOffsetWave[i] = CMap_getLineOffset(x1,y1,x2,y2)		// Used for sorting the lines, top to bottom
		lineSlopeWave[i] = CMap_getLineSlope(x1,y1,x2,y2)		// Used to calculate the normal to get at the cortical column
		i += 1
	while(i<lineCount)
	
	Print "Sorting the lines, top to bottom, based on where they cross of the y-axis."
	Sort lineOffsetWave,x1Wave,y1Wave,x2Wave,y2Wave,lineOffsetWave
	
	Print "Sorted lines:"
	i = 0
	do
		print "\t\tLine "+num2str(i+1)+": ("+num2str(Round(x1Wave[i]))+","+num2str(Round(y1Wave[i]))+") to ("+num2str(Round(x2Wave[i]))+","+num2str(Round(y2Wave[i]))+")"
		i += 1
	while(i<lineCount)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add concentric circle

Function CMap_addConcentricCircle(LayoutX,LayoutY,currRadius)
	Variable		LayoutX				// Location of postsynaptic cell, in pre-scaled layout coordinates
	Variable		LayoutY
	Variable		currRadius			// Radius of circle (µm) (NOT pre-scaled)
	
	WAVE		CMap_PixelsPerMicron
	NVAR		CMap_layoutScale							// Layout scale (% µm)
	
	Variable	r = currRadius*CMap_layoutScale/100

	doWindow/F CMap_layout	
	SetDrawLayer UserFront
	SetDrawEnv linefgc= (65535,65535,65535),dash= 11,fillpat= 0
	DrawOval LayoutX-r,LayoutY-r,LayoutX+r,LayoutY+r

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add cortical column boundary lines

Function CMap_addCorticalColumn()

	WAVE		CMap_PixelsPerMicron
	NVAR		CMap_layoutScale							// Layout scale (% µm)
	Variable	sc = CMap_layoutScale/100
	Variable	imSc											// Image scale (pixels/µm)
	imSc = CMap_PixelsPerMicron[0]

	Variable	xMargin = 20
	Variable	yMargin = 20
	Variable	imWidth = 512*sc
	Variable	imHeight = 512*sc

	NVAR		minX = CMap_minX
	NVAR		maxX = CMap_maxX
	NVAR		minY = CMap_minY
	NVAR		maxY = CMap_maxY

	WAVE		lineSlopeWave						// The slopes of all boundary lines
	WAVE		x1Wave,y1Wave,x2Wave,y2Wave			// The layer boundary lines
	WAVE		CMap_LayoutX,CMap_LayoutY			// Cell positions in layout coordinate system
	NVAR		CMap_columnWidth					// Cortical column width (µm)
	
//	The slope of a perpendicular line is -1/m. So the equation of the normal line looks
//	like y = (x1-x2)/(y2 - y1) * x + a constant.

	Variable	averageSlope = 0					// This is the average slope of all layer boundary lines
	Variable/G	CMap_angle = 0
	Variable	nLines = numpnts(x1Wave)
	
	if (nLines>0)	// Skip if there are no lines stored
		CMap_makeImageLayout()				// Recreate the layout of FOV images, thus clearing everything
		CMap_addLinesBackToLayout()			// Add the stored layer boundary lines back to the layout
		Make/O/N=(2+1+2+1+2) CMap_columnWaveX,CMap_columnWaveY		// two coordinates for each line, with a NaN (gap) between
		CMap_columnWaveX = NaN
		CMap_columnWaveY = NaN
		averageSlope = Mean(lineSlopeWave)
		if (averageSlope==0)
			print "\t\tWarning! All layer boundary lines are of exactly zero slope!"
			averageSlope += 1e-6		// Slope cannot be zero, or you get divide by zero
		endif
		CMap_angle = atan(averageSlope)*180/Pi
		// y = kx+m; m = y-kx; x = (y-m)/k
		Variable widthLine_m = CMap_LayoutY[0] - averageSlope*CMap_LayoutX[0]
		// Make column width line
		CMap_columnWaveX[6] = CMap_LayoutX[0]-cos(atan(averageSlope))*CMap_columnWidth/2*sc
		CMap_columnWaveY[6] = averageSlope*CMap_columnWaveX[6] + widthLine_m
		CMap_columnWaveX[7] = CMap_LayoutX[0]+cos(atan(averageSlope))*CMap_columnWidth/2*sc
		CMap_columnWaveY[7] = averageSlope*CMap_columnWaveX[7] + widthLine_m
		Variable eraseColumnWidthLine = 1		// This line was mostly just generated for debugging purposes
		// Make left column height line
		Variable perpSlope = -1/averageSlope
		Variable leftColumn_m = CMap_columnWaveY[6] - perpSlope*CMap_columnWaveX[6]				// Pass through column width line
		Variable leftCol_x1 = (yMargin - leftColumn_m)/perpSlope									// x = (y-m)/k for top of screen
		Variable leftCol_x2 = (yMargin-minY*sc+maxY*sc+imWidth/imSc - leftColumn_m)/perpSlope	// x = (y-m)/k for bottom of screen
		CMap_columnWaveX[0] = leftCol_x1
		CMap_columnWaveY[0] = yMargin
		CMap_columnWaveX[1] = leftCol_x2
		CMap_columnWaveY[1] = yMargin-minY*sc+maxY*sc+imWidth/imSc
		// Make right column height line
		Variable rightColumn_m = CMap_columnWaveY[7] - perpSlope*CMap_columnWaveX[7]				// Pass through column width line
		Variable rightCol_x1 = (yMargin - rightColumn_m)/perpSlope								// x = (y-m)/k for top of screen
		Variable rightCol_x2 = (yMargin-minY*sc+maxY*sc+imWidth/imSc - rightColumn_m)/perpSlope	// x = (y-m)/k for bottom of screen
		CMap_columnWaveX[3] = rightCol_x1
		CMap_columnWaveY[3] = yMargin
		CMap_columnWaveX[4] = rightCol_x2
		CMap_columnWaveY[4] = yMargin-minY*sc+maxY*sc+imWidth/imSc
		// Erase the column width line or not? Mostly just used for debugging...
		if (eraseColumnWidthLine)
			CMap_columnWaveX[6] = NaN
			CMap_columnWaveY[6] = NaN
			CMap_columnWaveX[7] = NaN
			CMap_columnWaveY[7] = NaN
		endif
		// Draw column lines as a polygon
		doWindow/F CMap_layout	
		SetDrawLayer UserFront
		// Draw this as a polygon, since DrawLine objects are presumed to be drawn by user to demarcate layer boundaries
		SetDrawEnv linefgc= (65535,65535,65535),dash= 11,fillpat= 0
		DrawPoly CMap_columnWaveX[0],CMap_columnWaveY[0],1,1,CMap_columnWaveX,CMap_columnWaveY
	else
		print "No layer lines are stored, so the direction of the cortical column cannot be calculated."
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add stored lines back to layout

Function CMap_addLinesBackToLayoutProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			print "--- REDRAW STORED LAYER BOUNDARY LINES IN LAYOUT ---"
			CMap_makeImageLayout()
			CMap_ZapXYtoLayoutXY()
			CMap_addLinesBackToLayout()
			break
	endswitch

	return 0

End

Function CMap_addLinesBackToLayout()

	if (exists("x1Wave")!=1)
		CMap_killLayoutLines()
	endif

	WAVE		x1Wave,y1Wave,x2Wave,y2Wave			// The layer boundary lines
	
	doWindow/F CMap_layout

	Variable	nLines = numpnts(x1Wave)
	Variable	i
	
	if (nLines>0)	// Skip loop if there are no lines stored
		i = 0
		do
			SetDrawLayer UserFront
			SetDrawEnv linefgc= (65535,65535,65535)
			DrawLine x1Wave[i],y1Wave[i],x2Wave[i],y2Wave[i]
			i += 1
		while(i<nLines)
	else
		print "No layer lines have been stored, there is nothing to draw."
	endif

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Kill stored layer lines

Function CMap_killLayoutLinesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			print "--- KILL STORED LAYER BOUNDARY LINES ---"
			print date(),time()
			CMap_killLayoutLines()
			CMap_makeImageLayout()
			break
	endswitch

	return 0

End

Function CMap_killLayoutLines()

	Make/O/N=(0) x1Wave,y1Wave,x2Wave,y2Wave,lineOffsetWave,lineSlopeWave

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Stats on cells in each layer

Function CMap_LayerStatsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- CALCULATE STATS ON CELLS IN EACH LAYER ---"
			print date(),time()
			CMap_doLayerStats(-1)
			break
	endswitch

	return 0

End

Function CMap_LayerStatsPopupProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			Print "--- CALCULATE STATS ON CELLS IN EACH LAYER ---"
			print date(),time()
			print "Using "+popStr
			CMap_doLayerStats(popNum)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function CMap_doLayerStats(whichPulse)
	Variable	whichPulse
	
	Variable/G	CMap_mostRecentlyAnalyzedPulseNumber = whichPulse

	CMap_KillLayerStatsPlots()			// Kill any old layer stats plots first of all

	CMap_makeImageLayout()				// Recreate the layout of FOV images, thus clearing everything
	CMap_addLinesBackToLayout()			// Add the stored layer boundary lines back to the layout
	CMap_ZapXYtoLayoutXY()				// Convert the FOV images XY zap points to the XY system of the layout
	CMap_addCorticalColumn()				// Add the cortical column boundary lines
	
	CMap_combineAllStoredAwaySynapticResponseData()	// Combine extracted synaptic data such as amp1 and PPR so that it is compatible with the layout representation
	
	WAVE		CMap_columnWaveX			// 0 and 1 - left line; 3 and 4 - right line
	WAVE		CMap_columnWaveY

	WAVE		CMap_LayoutAmp1
	WAVE		CMap_LayoutAmp2
	WAVE		CMap_LayoutAmp3
	WAVE		CMap_LayoutCV1
	WAVE		CMap_LayoutCV2
	WAVE		CMap_LayoutPPR	
	
	WAVE		CMap_LayoutMaxDepol
	WAVE		CMap_LayoutMaxDepolLoc	// Not used yet
	
	WAVE		CMAP_LayerLoc
	WAVE		CMAP_ColumnLoc
	
	NVAR		CMap_layoutScale		// Layout scale (% µm)

	NVAR		nTicksWait				// Delay to show analysis progress

	WAVE		CMap_LayoutX				// These converted coordinates are produced by CMap_ZapXYtoLayoutXY
	WAVE		CMap_LayoutY
	WAVE		CMap_LayoutStageZ		// This is the z coordinate in µm
	WAVE		CMap_LayoutResp
	Variable	nPoints = numpnts(CMap_LayoutX)

	WAVE/T		CMap_imageName
	WAVE		CMap_imageStart
	
	WAVE		x1Wave,y1Wave,x2Wave,y2Wave			// The layer boundary lines
	
	Variable	i,j
	Variable	nLines = numpnts(x1Wave)
	Variable	nImages
	
	String		currResponses
	
	NVAR		CMap_PPRthres
	Variable	minRespAmpForPPR = CMap_PPRthres*1e-3
	NVAR		CMap_RespThres
	Variable	minRespAmpFor1stAmp = CMap_RespThres*1e-3
	
	// Note to self: these are the waves to check out -- CMap_LayoutAmp1,CMap_LayoutAmp2,CMap_LayoutCV1,CMap_LayoutCV2,CMap_LayoutPPR
	// These are for filling with info: CMAP_LayerLoc,CMAP_ColumnLoc
	
	//// --- Go through all responses
	Variable	useThisResponse
	Duplicate/O CMap_LayoutAmp1,CMap_LayoutUseAmp,CMap_LayoutUsePPR
	CMap_LayoutUseAmp = NaN
	CMap_LayoutUsePPR = NaN
	i = 1
	do
		if (CMap_LayoutResp[i])								// If this has been tagged as a response, record amplitude
			if (CMap_LayoutAmp1[i]<=minRespAmpFor1stAmp)
				useThisResponse = CMap_LayoutAmp2[i]		// If first response fails, use the 2nd as the recorded amplitude
			else
				useThisResponse = CMap_LayoutAmp1[i]
			endif
			// Using the popup menu, the user may force the usage of a specific EPSP number
			if (whichPulse==1)
				useThisResponse = CMap_LayoutAmp1[i]	
			endif
			if (whichPulse==2)
				useThisResponse = CMap_LayoutAmp2[i]	
			endif
			if (whichPulse==3)
				useThisResponse = CMap_LayoutAmp3[i]	
			endif
			if (whichPulse==4)
				useThisResponse = CMap_LayoutMaxDepol[i]	
			endif
		else
			useThisResponse = NaN								// If not tagged as a response, set recorded amplitude to a blank value
		endif
		CMap_LayoutUseAmp[i] = useThisResponse
		if (CMap_LayoutResp[i])								// If this has been tagged as a response, _potentially_ record PPR
			if (CMap_LayoutAmp1[i]>minRespAmpForPPR)
				if (CMap_LayoutPPR[i]>0)						// Only use positive PPR values -- this is what will be recorded
					CMap_LayoutUsePPR[i] = CMap_LayoutPPR[i]
				endif
			endif
		endif
		i += 1
	while(i<nPoints)
	
	//// --- Analyze each layer ---
	Make/T/O/N=(6)	wLayerSourceLabels = {"Layer 1","Layer 2/3","Layer 4","Layer 5","Layer 6","WM"}
	Variable	isBelow
	Variable	isAbove
	Variable	isInLayer
	Make/O/N=(nLines+1)	wCellCount,wConnCount,wPercConnCount,wRespAmpMean,wRespAmpSEM,wRespPPRMean,wRespPPRSEM
	wCellCount = 0
	wConnCount = 0
	wPercConnCount = 0
	wRespAmpMean = 0
	wRespAmpSEM = 0
	wRespPPRMean = 0
	wRespPPRSEM = 0
	Make/T/O/N=(nLines+1)	wLayerLabel,wLayerNs,wLayerNs2,wLayerNs3
	wLayerLabel = wLayerSourceLabels[p]
	wLayerNs = ""
	wLayerNs2 = ""
	wLayerNs3 = ""
	Make/O/N=(nPoints,nLines+1)	wViolinLayers,wViolinPPRLayers		// For violin AND for box plots, despite the name!
	wViolinLayers = NaN								// This array is much larger than it has to be; trim it afterwards?
	wViolinPPRLayers = NaN
	print "\tALL CELLS:"
	i = 0
	do  // Go through layer boundary lines, starting with the top line, ending with the bottom line
		nImages = numpnts(CMap_imageName)
		SetDrawLayer/W=CMap_layout/K UserFront
		CMap_addLinesBackToLayout()			// Add the stored layer boundary lines back to the layout
		CMap_DrawLayoutXYsymbol(CMap_LayoutX[0],CMap_LayoutY[0],CMap_LayoutResp[0])				// Add the patched cell
		Make/O/N=0 workWave1,workWave2
		// Figure out which layer the recorded, postsynaptic cell is in
		j = 0	// WARNING! Zeroth data point is the recorded cell! Special case!
		if (i==0)
			isBelow = 1		// Point is below positive infinity
		else
			isBelow = CMap_BelowLine(CMap_LayoutX[j],CMap_LayoutY[j],x1Wave[i-1],y1Wave[i-1],x2Wave[i-1],y2Wave[i-1])
		endif
		if (i==nLines)
			isAbove = 1		// Point is above negative infinity
		else
			isAbove = CMap_AboveLine(CMap_LayoutX[j],CMap_LayoutY[j],x1Wave[i],y1Wave[i],x2Wave[i],y2Wave[i])
		endif
		isInLayer = (isAbove) %& (isBelow)
		if (isInLayer)
			CMAP_LayerLoc[j] = i
		endif
		// Next look at all the presynaptic cells
		j = 1	// WARNING! Zeroth data point is the recorded cell! So start at 1...
		do		// Go through zap points in layout coordinate system
			if (i==0)
				isBelow = 1		// Point is below positive infinity
			else
				isBelow = CMap_BelowLine(CMap_LayoutX[j],CMap_LayoutY[j],x1Wave[i-1],y1Wave[i-1],x2Wave[i-1],y2Wave[i-1])
			endif
			if (i==nLines)
				isAbove = 1		// Point is above negative infinity
			else
				isAbove = CMap_AboveLine(CMap_LayoutX[j],CMap_LayoutY[j],x1Wave[i],y1Wave[i],x2Wave[i],y2Wave[i])
			endif
			isInLayer = (isAbove) %& (isBelow)
			if ( isInLayer )
				CMAP_LayerLoc[j] = i
				wCellCount[i] += 1
				if (CMap_LayoutResp[j])
					wConnCount[i] += 1
					workWave1[numpnts(workWave1)] = {CMap_LayoutUseAmp[j]}
					wViolinLayers[j][i] = CMap_LayoutUseAmp[j]
					if (CMap_LayoutAmp1[j]>minRespAmpForPPR)
						if (CMap_LayoutPPR[j]>0)							// Only use positive PPR values
							workWave2[numpnts(workWave2)] = {CMap_LayoutPPR[j]}
							wViolinPPRLayers[j][i] = CMap_LayoutPPR[j]
						endif
					endif
				endif
			endif
			if (isInLayer)
				CMap_DrawLayoutXYsymbol(CMap_LayoutX[j],CMap_LayoutY[j],CMap_LayoutResp[j] ? -2 : 1)
			endif
			j += 1
		while(j<nPoints)
		print "\t\t"+wLayerSourceLabels[i]+": "+num2str(wConnCount[i])+" out of "+num2str(wCellCount[i])+" connected, for "+num2str(Round(wConnCount[i]/wCellCount[i]*100))+"% connectivity."
		if (numpnts(workWave1)>0)
			WaveStats/Q workWave1
			wRespAmpMean[i] = V_avg
			if (numpnts(workWave1)>2)
				wRespAmpSEM[i] = V_SEM
			endif
			print "\t\t\tResponse amplitude: "+num2str(wRespAmpMean[i])+" ± "+num2str(wRespAmpSEM[i])+" mV, n = "+num2str(V_npnts)
		endif
		if (numpnts(workWave2)>0)
			WaveStats/Q workWave2
			wRespPPRMean[i] = V_avg
			if (numpnts(workWave2)>2)
				wRespPPRSEM[i] = V_SEM
			endif
			print "\t\t\tPPR: "+num2str(wRespPPRMean[i])+" ± "+num2str(wRespPPRSEM[i])+" mV, n = "+num2str(V_npnts)
		endif
		wLayerNs[i] = " "+num2str(wConnCount[i])+"/"+num2str(wCellCount[i])
		wLayerNs2[i] = " "+num2str(wConnCount[i])
		Duplicate/O/R=[][i] wViolinPPRLayers,dummyW
		WaveStats/Q dummyW
		wLayerNs3[i] = " "+num2str(V_npnts)
		doUpdate
		JT_WaitNTicks(nTicksWait)
		i += 1
	while(i<nLines+1)	// Has to go +1 to account for below the last line
	wPercConnCount = wConnCount/wCellCount*100
	JT_NaNsBecomeZero(wPercConnCount)
	
	//// --- Analyze THE COLUMN for each layer ---
	//	CMap_columnWaveX & Y	 -- index 0 and 1 are left line; index 3 and 4 are right line
	Variable	isLeftOf
	Variable	isRightOf
	Variable	isInColumn
	Make/O/N=(nLines+1)	wColumnCellCount,wColumnConnCount,wPercColumnConnCount,wColAmpMean,wColAmpSEM,wColPPRMean,wColPPRSEM
	wColumnCellCount = 0
	wColumnConnCount = 0
	wPercColumnConnCount = 0
	wColAmpMean = 0
	wColAmpSEM = 0
	wColPPRMean = 0
	wColPPRSEM = 0
	Make/T/O/N=(nLines+1)	wColumnNs,wColumnNs2
	wColumnNs = ""
	wColumnNs2 = ""
	Make/O/N=(nPoints,nLines+1)	wViolinColumn		// For violin and box plots
	wViolinColumn = NaN								// This array is much larger than it has to be; trim it afterwards?
	print "\tIN COLUMN:"
	i = 0
	do  // Go through layer boundary lines, starting with the top line, ending with the bottom line
		nImages = numpnts(CMap_imageName)
		SetDrawLayer/W=CMap_layout/K UserFront
		CMap_addLinesBackToLayout()			// Add the stored layer boundary lines back to the layout
		CMap_addCorticalColumn()				// Add the cortical column boundary lines
		CMap_DrawLayoutXYsymbol(CMap_LayoutX[0],CMap_LayoutY[0],CMap_LayoutResp[0])				// Add the patched cell
		Make/O/N=0 workWave1,workWave2
		j = 1	// WARNING! Zeroth data point is the recorded cell! So start at 1...
		do		// Go through zap points in layout coordinate system
			// In layer?
			if (i==0)
				isBelow = 1		// Point is below positive infinity
			else
				isBelow = CMap_BelowLine(CMap_LayoutX[j],CMap_LayoutY[j],x1Wave[i-1],y1Wave[i-1],x2Wave[i-1],y2Wave[i-1])
			endif
			if (i==nLines)
				isAbove = 1		// Point is above negative infinity
			else
				isAbove = CMap_AboveLine(CMap_LayoutX[j],CMap_LayoutY[j],x1Wave[i],y1Wave[i],x2Wave[i],y2Wave[i])
			endif
			isInLayer = (isAbove) %& (isBelow)
			isRightOf = CMap_RightOfLine(CMap_LayoutX[j],CMap_LayoutY[j],CMap_columnWaveX[0],CMap_columnWaveY[0],CMap_columnWaveX[1],CMap_columnWaveY[1])
			isLeftOf = CMap_LeftOfLine(CMap_LayoutX[j],CMap_LayoutY[j],CMap_columnWaveX[3],CMap_columnWaveY[3],CMap_columnWaveX[4],CMap_columnWaveY[4])
			isInColumn = (isRightOf) %& (isLeftOf)
			if (isInColumn)
				CMAP_ColumnLoc[j] = 1
			else
				CMAP_ColumnLoc[j] = 0
			endif
			if ( (isInLayer) %& (isInColumn) )
				wColumnCellCount[i] += 1
				if (CMap_LayoutResp[j])
					wColumnConnCount[i] += 1
					workWave1[numpnts(workWave1)] = {CMap_LayoutUseAmp[j]}
					wViolinColumn[j][i] = CMap_LayoutUseAmp[j]
					if (CMap_LayoutAmp1[j]>minRespAmpForPPR)
						if (CMap_LayoutPPR[j]>0)							// Only use positive PPR values
							workWave2[numpnts(workWave2)] = {CMap_LayoutPPR[j]}
						endif
					endif
				endif
			endif
			if ( (isInLayer) %& (isInColumn) )
				CMap_DrawLayoutXYsymbol(CMap_LayoutX[j],CMap_LayoutY[j], CMap_LayoutResp[j] ? -2 : 1)
			endif
			j += 1
		while(j<nPoints)
		print "\t\t"+wLayerSourceLabels[i]+": "+num2str(wColumnConnCount[i])+" out of "+num2str(wColumnCellCount[i])+" connected, for "+num2str(Round(wColumnConnCount[i]/wColumnCellCount[i]*100))+"% connectivity."
		if (numpnts(workWave1)>0)
			WaveStats/Q workWave1
			wColAmpMean[i] = V_avg
			if (numpnts(workWave1)>2)
				wColAmpSEM[i] = V_SEM
			endif
			print "\t\t\tResponse amplitude: "+num2str(wColAmpMean[i])+" ± "+num2str(wColAmpSEM[i])+" mV, n = "+num2str(V_npnts)
		endif
		if (numpnts(workWave2)>0)
			WaveStats/Q workWave2
			wColPPRMean[i] = V_avg
			if (numpnts(workWave2)>2)
				wColPPRSEM[i] = V_SEM
			endif
			print "\t\t\tPPR: "+num2str(wColPPRMean[i])+" ± "+num2str(wColPPRSEM[i])
		endif
		wColumnNs[i] = " "+num2str(wColumnConnCount[i])+"/"+num2str(wColumnCellCount[i])
		wColumnNs2[i] = " "+num2str(wColumnConnCount[i])
		doUpdate
		JT_WaitNTicks(nTicksWait)
		i += 1
	while(i<nLines+1)	// Has to go +1 to account for below the last line
	wPercColumnConnCount = wColumnConnCount/wColumnCellCount*100
	JT_NaNsBecomeZero(wPercColumnConnCount)
	
	//// --- Radial analysis across all layers ---
	NVAR		CMap_radialStep
	NVAR		CMap_radialEnd
	Variable	nCircles = Floor(CMap_radialEnd/CMap_radialStep)
	Variable	currRadius = CMap_radialStep		// currRadius goes in µm
	Make/O/N=(nCircles)	wCircleCellCount,wCircleConnCount,wPercCircleConnCount,wCircleLabel,wCircleMean,wCircleSEM,wCirclePPRMean,wCirclePPRSEM
	wCircleCellCount = 0
	wCircleConnCount = 0
	wPercCircleConnCount = 0
	wCircleMean = 0
	wCircleSEM = 0
	wCirclePPRMean = 0
	wCirclePPRSEM = 0
	wCircleLabel = CMap_radialStep*p
	Make/O/T/N=(nCircles)	wCircleNs,wCircleNs2,wCircleNs3
	wCircleNs = ""
	wCircleNs2 = ""
	wCircleNs3 = ""
	Variable	isInCircle
	Variable	dist
	Variable	xDistSq,yDistSq,zDistSq			// The squared distances (µm^2)
	print "\tRADIAL ANALYSIS:"
	i = 0
	do  // Go through concentric circles
		SetDrawLayer/W=CMap_layout/K UserFront
		CMap_addLinesBackToLayout()			// Add the stored layer boundary lines back to the layout
		CMap_addConcentricCircle(CMap_LayoutX[0],CMap_LayoutY[0],currRadius-CMap_radialStep)		// Add inner circle
		CMap_addConcentricCircle(CMap_LayoutX[0],CMap_LayoutY[0],currRadius)						// Add outer circle
		CMap_DrawLayoutXYsymbol(CMap_LayoutX[0],CMap_LayoutY[0],CMap_LayoutResp[0])				// Add the patched cell
		Make/O/N=0 workWave1,workWave2
		j = 1	// WARNING! Zeroth data point is the recorded cell! So start at 1...
		do		// Go through zap points in layout coordinate system
			// In Circle?
			xDistSq = ((CMap_LayoutX[j]-CMap_LayoutX[0])/CMap_layoutScale*100)^2
			yDistSq = ((CMap_LayoutY[j]-CMap_LayoutY[0])/CMap_layoutScale*100)^2
			zDistSq = (CMap_LayoutStageZ[j]-CMap_LayoutStageZ[0])^2
			dist = sqrt(xDistSq + yDistSq + zDistSq)														// Distance from patched cell
			isInCircle = (dist <= currRadius) %& (dist > currRadius-CMap_radialStep)
//			dist = sqrt( (CMap_LayoutX[j]-CMap_LayoutX[0])^2 + (CMap_LayoutY[j]-CMap_LayoutY[0])^2)	// Distance from patched cell
//			isInCircle = (dist <= currRadius*CMap_layoutScale/100) %& (dist > (currRadius-CMap_radialStep)*CMap_layoutScale/100)
			if ( isInCircle )
				wCircleCellCount[i] += 1
				if (CMap_LayoutResp[j])
					wCircleConnCount[i] += 1
					workWave1[numpnts(workWave1)] = {CMap_LayoutUseAmp[j]}
					if (CMap_LayoutAmp1[j]>minRespAmpForPPR)
						if (CMap_LayoutPPR[j]>0)							// Only use positive PPR values
							workWave2[numpnts(workWave2)] = {CMap_LayoutPPR[j]}
						endif
					endif
				endif
			endif
			if ( isInCircle )
				CMap_DrawLayoutXYsymbol(CMap_LayoutX[j],CMap_LayoutY[j], CMap_LayoutResp[j] ? -2 : 1)
			endif
			j += 1
		while(j<nPoints)
		print "\t\tCircle "+num2str(i+1)+": "+num2str(wCircleConnCount[i])+" out of "+num2str(wCircleCellCount[i])+" connected, for "+num2str(Round(wCircleConnCount[i]/wCircleCellCount[i]*100))+"% connectivity."
		if (numpnts(workWave1)>0)
			WaveStats/Q workWave1
			wCircleMean[i] = V_avg
			if (numpnts(workWave1)>2)
				wCircleSEM[i] = V_SEM
			endif
			print "\t\t\tResponse amplitude: "+num2str(wCircleMean[i])+" ± "+num2str(wCircleSEM[i])+" mV, n = "+num2str(V_npnts)
		endif
		if (numpnts(workWave2)>0)
			WaveStats/Q workWave2
			wCirclePPRMean[i] = V_avg
			if (numpnts(workWave2)>2)
				wCirclePPRSEM[i] = V_SEM
			endif
			print "\t\t\tPPR: "+num2str(wCirclePPRMean[i])+" ± "+num2str(wCirclePPRSEM[i])
			wCircleNs3[i] = num2str(V_npnts)
		endif
		wCircleNs[i] = num2str(wCircleConnCount[i])+"/"+num2str(wCircleCellCount[i])
		wCircleNs2[i] = num2str(wCircleConnCount[i])
		doUpdate
		JT_WaitNTicks(nTicksWait*0.5)
		currRadius += CMap_radialStep
		i += 1
	while(i<nCircles)
	wPercCircleConnCount = wCircleConnCount/wCircleCellCount*100
	JT_NaNsBecomeZero(wPercCircleConnCount)

	//// --- Reset layout ---
	SetDrawLayer/W=CMap_layout/K UserFront
	CMap_addLinesBackToLayout()			// Add the stored layer boundary lines back to the layout
	CMap_addCorticalColumn()				// Add the cortical column boundary lines
	CMap_ZapXYtoLayoutXY()				// Convert the FOV images XY zap points to the XY system of the layout
	
	//// --- Display results ---
	CMap_PlotLayerStats()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make gamma-corrected LUT

Function CMap_updateGammaProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR		CMap_HeatmapGamma

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			CMap_makeGammaCorrectedLUT(CMap_HeatmapGamma)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function CMap_makeGammaCorrectedLUT(theGamma)
	Variable	theGamma

	ColorTab2Wave BlueHot256
	WAVE		M_colors
	Variable	nColorsIn = DimSize(M_colors,0)
	Variable	nColorsOut = 2^12
	Make/O/N=(nColorsOut,3) CMap_LUT
	Variable	i,j
	i = 0
	do
		j = floor( (i/nColorsOut)^(theGamma)*nColorsIn )
//		print i,j
		CMap_LUT[i][0] = M_colors[j][0]
		CMap_LUT[i][1] = M_colors[j][1]
		CMap_LUT[i][2] = M_colors[j][2]
		i += 1
	while(i<nColorsOut)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the heatmap of connected cells

Function CMap_CreateMatrix()

	WAVE		CMap_cellX
	WAVE		CMap_cellY
	WAVE		CMap_LayoutUseAmp
	WAVE		CMap_LayoutResp

	Variable	xMin,xMax
	Variable	yMin,yMax
	
	Variable	xNow,yNow,aNow
	Variable	pNow,qNow,paNow,qaNow
	Variable	p1,p2,q1,q2
	Variable	gaussDiam = 20
	Variable	fillScale = 3
	Variable	pad = gaussDiam*fillScale*1.05		// Add 5% slop for rounding errors (a hefty margin)
	
	WaveStats/Q	CMap_cellX
	xMin = V_min-pad
	xMax = V_max+pad
		
	WaveStats/Q	CMap_cellY
	yMin = V_min-pad
	yMax = V_max+pad
	
	Variable	StepSize = 2
	
	Variable	xN = floor( (xMax-xMin)/StepSize+1 )
	Variable	yN = floor( (yMax-yMin)/StepSize+1 )
	
	Make/O/N=(xN,yN) CMap_matrix
	CMap_matrix = 0
	SetScale/P x,xMin,StepSize,CMap_matrix
	SetScale/P y,yMin,StepSize,CMap_matrix

	paNow = 1/DimDelta(CMap_matrix,0)*gaussDiam /(2*sqrt(ln(2)))		// Conversion factor is so Gaussian half-width matches stated diameter gaussDiam
	qaNow = 1/DimDelta(CMap_matrix,1)*gaussDiam /(2*sqrt(ln(2)))

	Variable	n = numpnts(CMap_cellX)
	Variable	i
	i = 1			// Skip postsynaptic cell
	do
		if (CMap_LayoutResp[i])
			xNow = CMap_cellX[i]
			yNow = CMap_cellY[i]
			aNow = CMap_LayoutUseAmp[i]
			pNow = (xNow - DimOffset(CMap_matrix, 0))/DimDelta(CMap_matrix,0)
			qNow = (yNow - DimOffset(CMap_matrix, 1))/DimDelta(CMap_matrix,1)
			p1 = Round(pNow-paNow*fillScale)
			p2 = Round(pNow+paNow*fillScale)
			q1 = Round(qNow-qaNow*fillScale)
			q2 = Round(qNow+qaNow*fillScale)
			CMap_matrix[p1,p2][q1,q2] += aNow*exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))
		endif
		i += 1
	while(i<n)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Scrap all override values

Function CMap_scrapAllOverrideValues()

	doAlert/T="Are you sure?" 1,"Are you sure you want to scrap all override values?"
	if (V_flag==1)
		print "--- Scrapping all override values ---"
		print date(),time()
		CMap_doScrapAllOverrideValues()
	else
		print "Did not scrap any override values..."
	endif

End

Function CMap_doScrapAllOverrideValues()

	Variable		nLines = 5
	
	Make/O/N=(nLines)	CMap_OR_line
	Make/O/N=(nLines)	CMap_OR_resp
	Make/O/N=(nLines)	CMap_OR_amp1
	Make/O/N=(nLines)	CMap_OR_amp2
	Make/O/N=(nLines)	CMap_OR_amp3
	Make/O/N=(nLines)	CMap_OR_CV1
	Make/O/N=(nLines)	CMap_OR_CV2
	Make/O/N=(nLines)	CMap_OR_CV3
	Make/O/N=(nLines)	CMap_OR_PPR
	Make/O/N=(nLines)	CMap_OR_TPR

	CMap_doScrapAllOverrideValues2()

	CMap_OR_line = NaN
	CMap_OR_resp = NaN
	CMap_OR_amp1 = NaN
	CMap_OR_amp2 = NaN
	CMap_OR_amp3 = NaN
	CMap_OR_CV1 = NaN
	CMap_OR_CV2 = NaN
	CMap_OR_CV3 = NaN
	CMap_OR_PPR = NaN
	CMap_OR_TPR = NaN

End

Function CMap_doScrapAllOverrideValues2()		// Added to code at a later stage, so kludge this way to avoid bug

	Variable		nLines = 5

	Make/O/N=(nLines)	CMap_OR_maxDepol
	Make/O/N=(nLines)	CMap_OR_maxDepolLoc

	CMap_OR_maxDepol = NaN
	CMap_OR_maxDepolLoc = NaN

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Based on amp1, 2, and 3, calculate PPR and TPR automatically

Function CMap_autoSetSomeOverrideValuesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			print "Auto-calculating override values for PPR and TPR from amp 1, 2, and 3"
			print date(),time()
			CMap_doAutoSetSomeOverrideValuesProc()
			break
	endswitch

	return 0

End

Function CMap_doAutoSetSomeOverrideValuesProc()

	WAVE	CMap_OR_amp1
	WAVE	CMap_OR_amp2
	WAVE	CMap_OR_amp3
	WAVE	CMap_OR_PPR
	WAVE	CMap_OR_TPR

	Variable	nOverrides = numpnts(CMap_OR_amp1)
	Variable	i
	i = 0
	do
		CMap_OR_PPR[i] = CMap_OR_amp2[i]/CMap_OR_amp1[i]
		CMap_OR_TPR[i] = (CMap_OR_amp2[i]+CMap_OR_amp3[i])/(2*CMap_OR_amp1[i])
		i += 1
	while(i<nOverrides)
	
	DoWindow/F CMapOverrideTable

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Edit override values

Function CMap_editOverrideValuesProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			print date(),time()
			CMap_doEditOverrideValues()
			break
	endswitch

	return 0

End

Function CMap_doEditOverrideValues()

	print "--- INSTRUCTIONS FOR MANUALLY OVERRIDING SPECIIFC VALUES ---"
	print "\tCheck \"Override...\" before doing Layer Stats and then do Export."
	print "\tUncheck and redo Layer Stats to revert to automatically extracted values."
	print "\tBlanks (NaN) are ignored, so preserve original automatically extracted value."
	print "\tLine refers to the line number in the \"CMap Parameters\" table. Starts from zero."
	print "\tResponse refers to the response number for that line. Starts from zero."
	print "\tAmp1, 2, 3 refer to amplitude of EPSP 1, 2, and 3."
	print "\tCV1, 2, 3 refer to coefficient of variation of EPSP 1, 2, and 3."
	print "\tPPR refers to the paired-pulse ratio, or EPSP2/EPSP1."
	print "\tTPR refers to the triple-pulse ratio, or mean(EPSP2,EPSP3)/EPSP1 = (EPSP2+EPSP3)/(2*EPSP1)."
	print "\tMaxDepol is the peak depolarization, and MaxDepolLoc is its latency in ms."
	
	Variable		ScSc = PanelResolution("")/ScreenResolution
	
	if (Exists("CMap_OR_line"))
		WAVE	CMap_OR_line
		WAVE	CMap_OR_resp
		WAVE	CMap_OR_amp1
		WAVE	CMap_OR_amp2
		WAVE	CMap_OR_amp3
		WAVE	CMap_OR_CV1
		WAVE	CMap_OR_CV2
		WAVE	CMap_OR_CV3
		WAVE	CMap_OR_PPR
		WAVE	CMap_OR_TPR
		
		if (Exists("CMap_OR_maxDepol"))
			WAVE	CMap_OR_maxDepol
			WAVE	CMap_OR_maxDepolLoc
		else
			CMap_doScrapAllOverrideValues2()
			WAVE	CMap_OR_maxDepol
			WAVE	CMap_OR_maxDepolLoc
		endif

	else
		CMap_doScrapAllOverrideValues()
		WAVE	CMap_OR_line
		WAVE	CMap_OR_resp
		WAVE	CMap_OR_amp1
		WAVE	CMap_OR_amp2
		WAVE	CMap_OR_amp3
		WAVE	CMap_OR_CV1
		WAVE	CMap_OR_CV2
		WAVE	CMap_OR_CV3
		WAVE	CMap_OR_PPR
		WAVE	CMap_OR_TPR
		WAVE	CMap_OR_maxDepol
		WAVE	CMap_OR_maxDepolLoc
	endif

	Variable		Xpos = 100
	Variable		Ypos = 64
	Variable		Width = 1060
	Variable		Height = 300
	
	DoWindow/K CMapOverrideTable
	Edit/K=1/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Do override before Layer Stats and Export; blanks (NaN) preserve original value"
	DoWindow/C CMapOverrideTable
	AppendToTable	CMap_OR_line
	AppendToTable	CMap_OR_resp
	AppendToTable	CMap_OR_amp1
	AppendToTable	CMap_OR_amp2
	AppendToTable	CMap_OR_amp3
	AppendToTable	CMap_OR_CV1
	AppendToTable	CMap_OR_CV2
	AppendToTable	CMap_OR_CV3
	AppendToTable	CMap_OR_PPR
	AppendToTable	CMap_OR_TPR
	
	AppendToTable	CMap_OR_maxDepol
	AppendToTable	CMap_OR_maxDepolLoc

	ModifyTable title(	CMap_OR_line)="Line"
	ModifyTable title(	CMap_OR_resp)="Response"
	ModifyTable title(	CMap_OR_amp1)="Amp1"
	ModifyTable title(	CMap_OR_amp2)="Amp2"
	ModifyTable title(	CMap_OR_amp3)="Amp3"
	ModifyTable title(	CMap_OR_CV1)="CV1"
	ModifyTable title(	CMap_OR_CV2)="CV2"
	ModifyTable title(	CMap_OR_CV3)="CV3"
	ModifyTable title(	CMap_OR_PPR)="PPR"
	ModifyTable title(	CMap_OR_TPR)="TPR"

	ModifyTable title(	CMap_OR_maxDepol)="MaxDep"
	ModifyTable title(	CMap_OR_maxDepolLoc)="MaxDepLoc"

	Create_CMapTable()		// Recreate to be on the safe side
	DoWindow/F CMapOverrideTable
	AutoPositionWindow/M=1/R=CMapTable CMapOverrideTable

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot stats on cells in each layer

Function CMap_redrawLayerStatsGraphsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			print date(),time()
			CMap_PlotLayerStats()
			break
	endswitch

	return 0

End

Function CMap_PlotLayerStats()

	variable/G JT_SigLinesFlipY = 1			// Flag: Draw error bars on other side of graph to account for ModifyGraph swapXY = 1 bug

	controlInfo/W=CMapPanel PlotModePopup
	Variable	plotModeVar = V_Value
	
	Variable	i
	Variable	boxPlotMarkerSize = 4
	
	// Layer connectivity
	WAVE		wPercConnCount
	WAVE/T		wLayerLabel
	WAVE/T		wLayerNs
	WAVE		wConnCount
	WAVE		wCellCount
	DoWindow/K LayerStatsGraph1
	Display /W=(143,528,538,736) wPercConnCount,wPercConnCount vs wLayerLabel as "Layer connectivity"
	DoWindow/C LayerStatsGraph1
	ModifyGraph mode(wPercConnCount)=3
	ModifyGraph rgb(wPercConnCount)=(0,0,0),rgb(wPercConnCount#1)=(33536,40448,47872)
	ModifyGraph hbFill(wPercConnCount#1)=2
	ModifyGraph toMode(wPercConnCount)=-1
	ModifyGraph useBarStrokeRGB(wPercConnCount#1)=1
	ModifyGraph textMarker(wPercConnCount)={wLayerNs,"default",1,0,4,0.00,0.00}
	ModifyGraph manTick(left)={0,10,0,0},manMinor(left)={1,50}
	Label left "connectivity (%)"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	// Add sigLines
	CMap_createConnSigMatrix(wConnCount,wCellCount)
	WAVE	sigMatrix
	JT_SigLinesFlipY = 1
	JT_AllBarsSigStars("",sigMatrix)
	JT_SigLinesFlipY = 0
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Connectivity across layers\\f00\r"+num2str(sum(wConnCount))+"/"+num2str(sum(wCellCount))+" connected ("+num2str(round(sum(wConnCount)/sum(wCellCount)*100))+"%)"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"

	// Column connectivity
	WAVE		wPercColumnConnCount
	WAVE/T		wColumnNs
	WAVE		wColumnConnCount
	WAVE		wColumnCellCount
	DoWindow/K LayerStatsGraph2
	Display /W=(143,528,538,736) wPercColumnConnCount,wPercColumnConnCount vs wLayerLabel as "Column connectivity"
	DoWindow/C LayerStatsGraph2
	ModifyGraph mode(wPercColumnConnCount)=3
	ModifyGraph rgb(wPercColumnConnCount)=(0,0,0),rgb(wPercColumnConnCount#1)=(33536,40448,47872)
	ModifyGraph hbFill(wPercColumnConnCount#1)=2
	ModifyGraph toMode(wPercColumnConnCount)=-1
	ModifyGraph useBarStrokeRGB(wPercColumnConnCount#1)=1
	ModifyGraph textMarker(wPercColumnConnCount)={wColumnNs,"default",1,0,4,0.00,0.00}
	ModifyGraph manTick(left)={0,10,0,0},manMinor(left)={1,50}
	Label left "connectivity (%)"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	// Add sigLines
	CMap_createConnSigMatrix(wColumnConnCount,wColumnCellCount)
	WAVE	sigMatrix
	JT_SigLinesFlipY = 1
	JT_AllBarsSigStars("",sigMatrix)
	JT_SigLinesFlipY = 0
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Connectivity within column\\f00\r"+num2str(sum(wColumnConnCount))+"/"+num2str(sum(wColumnCellCount))+" connected ("+num2str(round(sum(wColumnConnCount)/sum(wColumnCellCount)*100))+"%)"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"

	// Radial connectivity
	WAVE		wPercCircleConnCount
	WAVE		wCircleLabel
	WAVE/T		wCircleNs
	NVAR		CMap_radialStep
	NVAR		CMap_radialEnd
	WAVE		wCircleConnCount
	WAVE		wCircleCellCount
	DoWindow/K LayerStatsGraph3
	Display /W=(35,53,572,389) wPercCircleConnCount vs wCircleLabel as "Radial connectivity"
	DoWindow/C LayerStatsGraph3
	ModifyGraph mode=5
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	ModifyGraph manTick(left)={0,10,0,0},manMinor(left)={1,0}
	SetAxis/A/N=1/E=1 left
	SetAxis bottom,0,(Round(CMap_radialEnd/CMap_radialStep)-1)*CMap_radialStep
	Label left "connectivity (%)"
	Label bottom "radius (µm)"
	AppendToGraph wPercCircleConnCount vs wCircleLabel
	ModifyGraph mode(wPercCircleConnCount#1)=3
	ModifyGraph rgb(wPercCircleConnCount#1)=(0,0,0)
	ModifyGraph textMarker(wPercCircleConnCount#1)={wCircleNs,"default",1,0,1,0.00,0.00}
	ModifyGraph offset(wPercCircleConnCount#1)={CMap_radialStep/2,0}
	K0 = 0;
	i = 0
	Variable	fitStart = 0
	do
		if (wPercCircleConnCount[i]>0)
			fitStart = i
			i = Inf
		endif
		i += 1
	while (i<numpnts(wPercCircleConnCount))
	CurveFit/H="100"/Q/M=2/W=0 exp, wPercCircleConnCount[fitStart,]/X=wCircleLabel/D
	ModifyGraph lstyle(fit_wPercCircleConnCount)=1
	ReorderTraces wPercCircleConnCount#1,{fit_wPercCircleConnCount}
	ModifyGraph rgb(fit_wPercCircleConnCount)=(65535,0,0)//,65535/2)
	WAVE		W_coef
	Variable/G	CMap_radialTau = 1/W_coef[2]
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01Radial connectivity\\f00\r"+num2str(sum(wCircleConnCount))+"/"+num2str(sum(wCircleCellCount))+" connected ("+num2str(round(sum(wCircleConnCount)/sum(wCircleCellCount)*100))+"%)\r\\s(fit_wPercCircleConnCount) tau = "+num2str(round(CMap_radialTau))+" µm"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"
	ModifyGraph margin(left)=48,nticks(left)=3
	
	// Layer amplitude
	DoWindow/K LayerStatsGraph4
	Display /W=(143,528,538,736)  as "Layer amplitudes"
	DoWindow/C LayerStatsGraph4
	switch(plotModeVar)
		case 1:
			WAVE		wRespAmpMean
			WAVE		wRespAmpSEM
			WAVE/T	wLayerNs2
			WAVE		wViolinLayers
			Duplicate/O wRespAmpMean,wRespAmpMean2
			wRespAmpMean2 = wRespAmpMean+wRespAmpSEM
//			wRespAmpSEM = wRespAmpSEM[p] == 0 ? NaN : wRespAmpSEM[p]		// Remove the errorbar for zero SEM
//			wRespAmpMean = wRespAmpMean[p] == 0 ? NaN : wRespAmpMean[p]	// Remove the bar for zero SEM
			AppendToGraph wRespAmpMean vs wLayerLabel
			ModifyGraph mode(wRespAmpMean)=5
			ModifyGraph hbFill(wRespAmpMean)=2
			ModifyGraph rgb(wRespAmpMean)=(33536,40448,47872)
			ModifyGraph useBarStrokeRGB(wRespAmpMean)=1
			Label left "amplitude (mV)\\u#2"
			SetAxis/A/N=2 left,0,*
			SetAxis/A/R bottom
			ModifyGraph prescaleExp(left)=3,notation(left)=1
			ErrorBars wRespAmpMean Y,wave=(wRespAmpSEM,wRespAmpSEM)
			AppendToGraph wRespAmpMean2 vs wLayerLabel
			ModifyGraph toMode(wRespAmpMean)=-1,mode(wRespAmpMean2)=3
			ModifyGraph rgb(wRespAmpMean2)=(0,0,0),textMarker(wRespAmpMean2)={wLayerNs2,"default",1,0,4,0.00,0.00}
			// Add sigLines
			CMap_createSigMatrix(wViolinLayers)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
		case 2:
			WAVE		wViolinLayers
			AppendBoxPlot wViolinLayers vs wLayerLabel
			ModifyGraph mode=4
			Label left "amplitude (mV)\\u#2"
			SetAxis/A/R bottom
			ModifyBoxPlot trace=wViolinLayers,markers={-1,8,8},markersFilled={1,1,1,1,1},medianMarkerColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinLayers,medianMarkerStrokeColor=(0,0,0),dataColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinLayers,dataFillColor=(33536,40448,47872),outlierColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinLayers,outlierFillColor=(33536,40448,47872),farOutlierColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinLayers,farOutlierFillColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinLayers,markerSizes={boxPlotMarkerSize,boxPlotMarkerSize,boxPlotMarkerSize},boxFill=(61166,61166,61166)
			ModifyBoxPlot trace=wViolinLayers,dataStrokeColor=(0,0,0),outlierStrokeColor=(0,0,0)
			ModifyBoxPlot trace=wViolinLayers,farOutlierStrokeColor=(0,0,0),whiskerMethod=3
			SetAxis/A/N=2 left,0,*
			// Add sigLines
			CMap_createSigMatrix(wViolinLayers)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
		case 3:
			WAVE		wViolinLayers
			AppendViolinPlot wViolinLayers vs wLayerLabel
			ModifyGraph mode=4
			ModifyGraph fSize=10
			Label left "amplitude (mV)\\u#2"
			SetAxis/A/N=2 left,0,*
			SetAxis/A/R bottom
			ModifyViolinPlot trace=wViolinLayers,MarkerColor=(33536,40448,47872),MarkerFilled=1
			ModifyViolinPlot trace=wViolinLayers,FillColor=(61166,61166,61166),CurveExtension=2
			ModifyViolinPlot trace=wViolinLayers,ShowMedian,MedianMarkerStrokeColor=(0,0,0),MarkerSize=5,MedianMarkerSize=5,MedianMarkerThick=1
			ModifyViolinPlot trace=wViolinLayers,MedianMarkerFilled=1,MedianMarkerFillColor=(0,0,0)
			ModifyViolinPlot trace=wViolinLayers,CloseOutline
			// Add sigLines
			CMap_createSigMatrix(wViolinLayers)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
	endswitch
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01EPSP amplitude across layers\\f00"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"

	// Column amplitude
	DoWindow/K LayerStatsGraph5
	Display /W=(143,528,538,736)  as "Column amplitudes"
	DoWindow/C LayerStatsGraph5
	switch(plotModeVar)
		case 1:
			WAVE		wColAmpMean
			WAVE		wColAmpSEM
			WAVE/T	wColumnNs2
			WAVE		wViolinColumn
			Duplicate/O wColAmpMean,wColAmpMean2
			wColAmpMean2 = wColAmpMean+wColAmpSEM
//			wColAmpSEM = wColAmpSEM[p] == 0 ? NaN : wColAmpSEM[p]
//			wColAmpMean = wColAmpMean[p] == 0 ? NaN : wColAmpMean[p]
			AppendToGraph wColAmpMean vs wLayerLabel
			ModifyGraph mode(wColAmpMean)=5
			ModifyGraph hbFill(wColAmpMean)=2
			ModifyGraph rgb(wColAmpMean)=(33536,40448,47872)
			ModifyGraph useBarStrokeRGB(wColAmpMean)=1
			Label left "amplitude (mV)\\u#2"
			SetAxis/A/N=2 left,0,*
			SetAxis/A/R bottom
			ModifyGraph prescaleExp(left)=3,notation(left)=1
			ErrorBars wColAmpMean Y,wave=(wColAmpSEM,wColAmpSEM)
			AppendToGraph wColAmpMean2 vs wLayerLabel
			ModifyGraph toMode(wColAmpMean)=-1,mode(wColAmpMean2)=3
			ModifyGraph rgb(wColAmpMean2)=(0,0,0),textMarker(wColAmpMean2)={wColumnNs2,"default",1,0,4,0.00,0.00}
			// Add sigLines
			CMap_createSigMatrix(wViolinColumn)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
		case 2:
			WAVE		wViolinColumn
			AppendBoxPlot wViolinColumn vs wLayerLabel
			ModifyGraph mode=4
			Label left "amplitude (mV)\\u#2"
			SetAxis/A/R bottom
			ModifyBoxPlot trace=wViolinColumn,markers={-1,8,8},markersFilled={1,1,1,1,1},medianMarkerColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinColumn,medianMarkerStrokeColor=(0,0,0),dataColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinColumn,dataFillColor=(33536,40448,47872),outlierColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinColumn,outlierFillColor=(33536,40448,47872),farOutlierColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinColumn,farOutlierFillColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinColumn,markerSizes={boxPlotMarkerSize,boxPlotMarkerSize,boxPlotMarkerSize},boxFill=(61166,61166,61166)
			ModifyBoxPlot trace=wViolinColumn,dataStrokeColor=(0,0,0),outlierStrokeColor=(0,0,0)
			ModifyBoxPlot trace=wViolinColumn,farOutlierStrokeColor=(0,0,0),whiskerMethod=3
//			SetAxis/A/N=1/E=1 Left
			SetAxis/A/N=2 left,0,*
			// Add sigLines
			CMap_createSigMatrix(wViolinColumn)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
		case 3:
			WAVE		wViolinColumn
			AppendViolinPlot wViolinColumn vs wLayerLabel
			ModifyGraph mode=4
			ModifyGraph fSize=10
			Label left "amplitude (mV)\\u#2"
			SetAxis/A/N=2 left,0,*
			SetAxis/A/R bottom
			ModifyViolinPlot trace=wViolinColumn,MarkerColor=(33536,40448,47872),MarkerFilled=1
			ModifyViolinPlot trace=wViolinColumn,FillColor=(61166,61166,61166),CurveExtension=2
			ModifyViolinPlot trace=wViolinColumn,ShowMedian,MedianMarkerStrokeColor=(0,0,0),MarkerSize=5,MedianMarkerSize=5,MedianMarkerThick=1
			ModifyViolinPlot trace=wViolinColumn,MedianMarkerFilled=1,MedianMarkerFillColor=(0,0,0)
			ModifyViolinPlot trace=wViolinColumn,CloseOutline
			// Add sigLines
			CMap_createSigMatrix(wViolinColumn)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
	endswitch
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01EPSP amplitude within column\\f00"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"

	// Radial amplitudes
	WAVE		wCircleMean
	WAVE		wCircleSEM
	WAVE/T		wCircleNs2
	Duplicate/O wCircleMean,wCircleMean2
	wCircleMean2 = wCircleMean+wCircleSEM
	DoWindow/K LayerStatsGraph6
	Display /W=(35,53,572,389) wCircleMean vs wCircleLabel as "Radial amplitudes"
	DoWindow/C LayerStatsGraph6
	ModifyGraph mode=5
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	SetAxis/A/N=1 left
	SetAxis bottom,0,(Round(CMap_radialEnd/CMap_radialStep)-1)*CMap_radialStep
	AppendToGraph wCircleMean vs wCircleLabel
	ModifyGraph mode(wCircleMean#1)=2
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph offset(wCircleMean#1)={CMap_radialStep/2,0}
	ErrorBars wCircleMean#1 Y,wave=(wCircleSEM,wCircleSEM)
	AppendToGraph wCircleMean2 vs wCircleLabel
	ModifyGraph offset(wCircleMean2)={CMap_radialStep/2,0}
	ModifyGraph toMode(wCircleMean)=-1,mode(wCircleMean2)=3
	ModifyGraph rgb(wCircleMean2)=(0,0,0),textMarker(wCircleMean2)={wCircleNs2,"default",1,0,1,0.00,0.00}
	Label left "amplitude (mV)\\u#2"
	Label bottom "radius (µm)"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01Radial EPSP amplitude\\f00"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"
	ModifyGraph margin(left)=48,nticks(left)=3
	
	// EPSP histogram
	Variable 	logNormHist = 1
	WAVE		CMap_LayoutUseAmp
	if (logNormHist)
		CMap_logBinHist()
	else
		CMap_BinHist()
	endif
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"

	// Connectivity map
	WAVE		CMap_LayoutX
	WAVE		CMap_LayoutY
	WAVE		CMap_LayoutMarkers
	NVAR		CMap_angle
	NVAR		CMap_layoutScale
	Variable	patchedX
	Variable	patchedY
	Duplicate/O CMap_LayoutX,CMap_cellX
	Duplicate/O CMap_LayoutY,CMap_cellY
	CMap_Rotate(-CMap_angle,CMap_cellX,CMap_cellY)	// Rotate so pial surface is up
	CMap_cellX /= (CMap_layoutScale/100)			// Convert to µm
	CMap_cellY /= (CMap_layoutScale/100)
	patchedX = CMap_cellX[0]
	patchedY = CMap_cellY[0]
	CMap_cellX -= patchedX							// Make patched cell the x-axis origin
	WAVE		x1Wave,y1Wave,x2Wave,y2Wave			// The layer boundary lines
	Duplicate/O x1Wave,CMap_LLx1
	Duplicate/O y1Wave,CMap_LLy1
	CMap_Rotate(-CMap_angle,CMap_LLx1,CMap_LLy1)
	CMap_LLx1 /= (CMap_layoutScale/100)
	CMap_LLy1 /= (CMap_layoutScale/100)
	CMap_LLx1 -= patchedX
	Duplicate/O x2Wave,CMap_LLx2
	Duplicate/O y2Wave,CMap_LLy2
	CMap_Rotate(-CMap_angle,CMap_LLx2,CMap_LLy2)
	CMap_LLx2 /= (CMap_layoutScale/100)
	CMap_LLy2 /= (CMap_layoutScale/100)
	CMap_LLx2 -= patchedX
	
	Variable	topLineValueAtXZero = CMap_getLineOffset(CMap_LLx1[0],CMap_LLy1[0],CMap_LLx2[0],CMap_LLy2[0])
	CMap_cellY -= topLineValueAtXZero				// Make top line value at x=0 the y-axis origin
	CMap_LLy1 -= topLineValueAtXZero
	CMap_LLy2 -= topLineValueAtXZero
	
	DoWindow/K LayerStatsGraph8
	Display /W=(1391,160,2187,922) CMap_cellY vs CMap_cellX as "Connectivity map"
	DoWindow/C LayerStatsGraph8
	ModifyGraph mode=3
	ModifyGraph marker=19
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph zmrkNum(CMap_cellY)={CMap_LayoutMarkers}
	ModifyGraph mrkThick(CMap_cellY)=1
	ModifyGraph opaque(CMap_cellY)=1									// Fill unconnected with white

	// Add response amplitude colouring
	AppendToGraph CMap_cellY vs CMap_cellX
	WaveStats/Q CMap_LayoutUseAmp
	Variable	maxColVal = round(V_max*1e3/3)*1e-3
	if (maxColVal < 1e-3)
		maxColVal = 1e-3
	endif
	if (0)
		ModifyGraph zColor(CMap_cellY#1)={CMap_LayoutUseAmp,0,maxColVal,Rainbow,1}
	else
		ModifyGraph zColor(CMap_cellY#1)={CMap_LayoutUseAmp,0,*,Rainbow,1}
	endif
	ModifyGraph mode(CMap_cellY#1)=3,marker(CMap_cellY#1)=19,mrkThick(CMap_cellY#1)=0
//	ModifyGraph msize(CMap_cellY#1)=6
	ModifyGraph mrkThick(CMap_cellY#1)=1
	ModifyGraph opaque(CMap_cellY#1)=1,useMrkStrokeRGB(CMap_cellY#1)=1,mrkStrokeRGB(CMap_cellY#1)=(33536,40448,47872)

	// Special case for postsynaptic cell
	Make/O/N=(1) postY,postX
	postY = CMap_cellY[0]
	postX = CMap_cellX[0]
	AppendToGraph postY vs postX
	ModifyGraph rgb(postY)=(0,0,0)
	ModifyGraph rgb(postY)=(65535,65535,65535),useMrkStrokeRGB(postY)=1
	ModifyGraph msize(postY)=8,mrkThick(postY)=1
	ModifyGraph mode(postY)=3,marker(postY)=60
		
	Label Left,"µm"
	Label Bottom,"µm"
	ModifyGraph width={Plan,1,bottom,left}
	SetAxis/A/R/N=1 left,*,-60
	SetAxis/A/N=1 bottom
//	SetAxis/N=1 bottom,-200,500
	doUpdate
	GetAxis/Q bottom
	Variable	xLeft = V_min
	Variable	xRight = V_max
	Variable	yLeft
	Variable	yRight
	Variable	lineSlope,lineOffs
	
	Variable	nLines = numpnts(x1Wave)
	Variable	mapFSize=9
	Make/O/N=(0) CMap_LLplotX,CMap_LLplotY			// For plotting only
	if (nLines>0)											// Skip loop if there are no lines stored
		i = 0
		do
			lineSlope = CMap_getLineSlope(CMap_LLx1[i],CMap_LLy1[i],CMap_LLx2[i],CMap_LLy2[i])
			lineOffs = CMap_getLineOffset(CMap_LLx1[i],CMap_LLy1[i],CMap_LLx2[i],CMap_LLy2[i])
			yLeft = lineSlope*xLeft + lineOffs
			yRight = lineSlope*xRight + lineOffs
			CMap_LLplotX[numpnts(CMap_LLplotX)] = {xLeft}
			CMap_LLplotY[numpnts(CMap_LLplotY)] = {yLeft}
			CMap_LLplotX[numpnts(CMap_LLplotX)] = {xRight}
			CMap_LLplotY[numpnts(CMap_LLplotY)] = {yRight}
			CMap_LLplotX[numpnts(CMap_LLplotX)] = {NaN}
			CMap_LLplotY[numpnts(CMap_LLplotY)] = {NaN}
			SetDrawEnv xcoord= bottom,ycoord= left,textyjust= 2,fname= "Arial",fstyle= 3,fsize= mapFSize
			DrawText xLeft,yLeft,wLayerLabel[i+1]
			if (i==0)
				SetDrawEnv xcoord= bottom,ycoord= left,textyjust= 0,fname= "Arial",fstyle= 3,fsize= mapFSize
				DrawText xLeft,yLeft,wLayerLabel[0]
			endif
			i += 1
		while(i<nLines)
	endif
	AppendToGraph CMap_LLplotY vs CMap_LLplotX
	ModifyGraph lstyle(CMap_LLplotY)=11,rgb(CMap_LLplotY)=(0,0,0)
	ReorderTraces CMap_cellY,{CMap_LLplotY}
	ModifyGraph fSize=10
	ModifyGraph grid=2,gridRGB=(34952,34952,34952)
	doUpdate
	GetAxis/Q Bottom
	String locStr = "RB"
	Variable	scaleBarRight = 1
	if (abs(V_min)>abs(V_max))
		locStr = "LB"
		scaleBarRight = 0
	endif
	ColorScale/C/N=text0/A=$(locStr)/X=0.00/Y=0.00 trace=CMap_cellY#1, heightPct=25, widthPct=3, fsize=10,"\\u#2amplitude (mV)"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"
	// Add column lines
	SetDrawEnv xcoord= bottom,ycoord= left,fname= "Arial",fstyle= 3,fsize= mapFSize
	SetDrawEnv textxjust= 1,textyjust= 2,ycoord= prel
	DrawText 0,0,"Column"
	NVAR		CMap_columnWidth					// Cortical column width (µm)
	SetDrawLayer UserBack
	SetDrawEnv xcoord= bottom,fillfgc= (61166,61166,61166),linethick= 0.00
	DrawRect -CMap_columnWidth/2,0,CMap_columnWidth/2,1
	SetDrawLayer UserFront	
	String legStr = ""
	legStr += num2str(sum(wConnCount))+"/"+num2str(sum(wCellCount))+" = "+num2str(round(sum(wConnCount)/sum(wCellCount)*100))+"%\r"
	WaveStats/Q CMap_LayoutUseAmp
	legStr += num2str(Round(V_avg*1e3*1e2)/1e2)+" ± "+num2str(Round(V_SEM*1e3*1e2)/1e2)+" mV"
	Legend/C/N=text1/J/F=0/B=1/X=0.00/Y=0.00 legStr
	
	// Heatmap
	Variable	pad = 0.01
	CMap_CreateMatrix()
	NVAR		CMap_HeatmapGamma
	CMap_makeGammaCorrectedLUT(CMap_HeatmapGamma)
	WAVE		CMap_matrix
	DoWindow/K LayerStatsGraph11
	NewImage/S=0 CMap_matrix
	JT_NameWin("LayerStatsGraph11","Connectivity heatmap")
	ModifyImage CMap_matrix ctab= {*,*,CMap_LUT,0}
	// Postsyn cell
	AppendToGraph/T postY vs postX
	ModifyGraph rgb(postY)=(65535,65535,65535)
	ModifyGraph msize(postY)=8							
	ModifyGraph mode(postY)=3,marker(postY)=60
	ModifyGraph mrkThick(postY)=1,useMrkStrokeRGB(postY)=1
	ModifyGraph mrkStrokeRGB(postY)=(0,26611,65535)
	// Layers
	doUpdate
	GetAxis/Q top
	xLeft = V_min
	xRight = V_max
	Make/O/N=(0) CMap_LLplotX2,CMap_LLplotY2			// For plotting only
	if (nLines>0)												// Skip loop if there are no lines stored
		i = 0
		do
			lineSlope = CMap_getLineSlope(CMap_LLx1[i],CMap_LLy1[i],CMap_LLx2[i],CMap_LLy2[i])
			lineOffs = CMap_getLineOffset(CMap_LLx1[i],CMap_LLy1[i],CMap_LLx2[i],CMap_LLy2[i])
			yLeft = lineSlope*xLeft + lineOffs
			yRight = lineSlope*xRight + lineOffs
			CMap_LLplotX2[numpnts(CMap_LLplotX2)] = {xLeft}
			CMap_LLplotY2[numpnts(CMap_LLplotY2)] = {yLeft}
			CMap_LLplotX2[numpnts(CMap_LLplotX2)] = {xRight}
			CMap_LLplotY2[numpnts(CMap_LLplotY2)] = {yRight}
			CMap_LLplotX2[numpnts(CMap_LLplotX2)] = {NaN}
			CMap_LLplotY2[numpnts(CMap_LLplotY2)] = {NaN}
			SetDrawEnv xcoord= prel,ycoord= left,textyjust= 2,fname= "Arial",fstyle= 3,fsize= mapFSize,textrgb= (65535,65535,65535)
			DrawText pad,yLeft,wLayerLabel[i+1]
			if (i==0)
				SetDrawEnv xcoord= prel,ycoord= left,textyjust= 0,fname= "Arial",fstyle= 3,fsize= mapFSize,textrgb= (65535,65535,65535)
				DrawText pad,yLeft,wLayerLabel[0]
			endif
			i += 1
		while(i<nLines)
	endif
	AppendToGraph/T CMap_LLplotY2 vs CMap_LLplotX2
	ModifyGraph lstyle(CMap_LLplotY2)=11,rgb(CMap_LLplotY2)=(65535,65535,65535)
	// Add column lines
	SetDrawEnv xcoord= top,ycoord= prel,fname= "Arial",fstyle= 3,fsize= mapFSize,textrgb= (65535,65535,65535)
	SetDrawEnv textxjust= 1,textyjust= 2
	DrawText 0,0,"Column"
	SetDrawLayer UserFront
	SetDrawEnv xcoord= top,ycoord= prel,linefgc= (65535,65535,65535),linethick= 1,dash= 1
	DrawLine -CMap_columnWidth/2,0,-CMap_columnWidth/2,1
	SetDrawEnv xcoord= top,ycoord= prel,linefgc= (65535,65535,65535),linethick= 1,dash= 1
	DrawLine CMap_columnWidth/2,0,CMap_columnWidth/2,1
	// Scale bar
	doUpdate
	GetAxis/Q top
	Variable xScale = V_max-V_min
	SetDrawLayer UserFront
	SetDrawEnv linethick= 2,linefgc= (65535,65535,65535),fillpat= 0,xcoord= prel,ycoord= prel
	variable xScBar = pad		// Scale bar position X
	variable yScBar = pad		// Scale bar position Y
	variable	lenScBar = 100	// Scale bar length (µm)
	if (scaleBarRight)
		xScBar = 1 - lenScBar/xScale - pad
	endif
	DrawPoly xScBar,yScBar,1,1,{xScBar, yScBar, xScBar + lenScBar/xScale, yScBar}
	SetDrawEnv textxjust= 1,textyjust= 2,fname= "Arial",fstyle= 1, textrgb= (65535,65535,65535),fsize=9
	DrawText xScBar + lenScBar/xScale/2, yScBar, num2str(lenScBar)+" µm"

	ModifyGraph width={Plan,1,top,left}
	ColorScale/C/N=text0/A=$(locStr)/X=10.00/Y=5.00/B=(0,0,0)/G=(65535,65535,65535) image=CMap_matrix, heightPct=25, widthPct=3, fsize=10,"\\u#2amplitude (mV)"

	// Layer PPR
	DoWindow/K LayerStatsGraph9
	Display /W=(143,528,538,736)  as "Layer PPR"
	DoWindow/C LayerStatsGraph9
	WAVE		wViolinPPRLayers
	switch(plotModeVar)
		case 1:
			WAVE		wRespPPRMean
			WAVE		wRespPPRSEM
			WAVE/T		wLayerNs3
			Duplicate/O wRespPPRMean,wRespPPRMean2
			wRespPPRMean2 = wRespPPRMean+wRespPPRSEM
			wRespPPRSEM = wRespPPRSEM[p] == 0 ? NaN : wRespPPRSEM[p]		// Remove the errorbar for zero SEM
			wRespPPRMean = wRespPPRMean[p] == 0 ? NaN : wRespPPRMean[p]	// Remove the bar for zero SEM
			AppendToGraph wRespPPRMean vs wLayerLabel
			ModifyGraph mode(wRespPPRMean)=5
			ModifyGraph hbFill(wRespPPRMean)=2
			ModifyGraph rgb(wRespPPRMean)=(33536,40448,47872)
			ModifyGraph useBarStrokeRGB(wRespPPRMean)=1
			Label left "PPR\\u#2"
			SetAxis/A/N=1/E=0 left
			SetAxis/A/R bottom
			ErrorBars wRespPPRMean Y,wave=(wRespPPRSEM,wRespPPRSEM)
			AppendToGraph wRespPPRMean2 vs wLayerLabel
			ModifyGraph toMode(wRespPPRMean)=-1,mode(wRespPPRMean2)=3
			ModifyGraph rgb(wRespPPRMean2)=(0,0,0),textMarker(wRespPPRMean2)={wLayerNs3,"default",1,0,4,0.00,0.00}
			// Add sigLines
			CMap_createSigMatrix(wViolinPPRLayers)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
		case 2:
			WAVE		wViolinPPRLayers
			AppendBoxPlot wViolinPPRLayers vs wLayerLabel
			ModifyGraph mode=4
			Label left "PPR\\u#2"
			SetAxis/A/R bottom
			ModifyBoxPlot trace=wViolinPPRLayers,markers={-1,8,8},markersFilled={1,1,1,1,1},medianMarkerColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinPPRLayers,medianMarkerStrokeColor=(0,0,0),dataColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinPPRLayers,dataFillColor=(33536,40448,47872),outlierColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinPPRLayers,outlierFillColor=(33536,40448,47872),farOutlierColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinPPRLayers,farOutlierFillColor=(33536,40448,47872)
			ModifyBoxPlot trace=wViolinPPRLayers,markerSizes={boxPlotMarkerSize,boxPlotMarkerSize,boxPlotMarkerSize},boxFill=(61166,61166,61166)
			ModifyBoxPlot trace=wViolinPPRLayers,dataStrokeColor=(0,0,0),outlierStrokeColor=(0,0,0)
			ModifyBoxPlot trace=wViolinPPRLayers,farOutlierStrokeColor=(0,0,0),whiskerMethod=3
			SetAxis/A/N=2/E=0 left
			// Add sigLines
			CMap_createSigMatrix(wViolinPPRLayers)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
		case 3:
			WAVE		wViolinPPRLayers
			AppendViolinPlot wViolinPPRLayers vs wLayerLabel
			ModifyGraph mode=4
			ModifyGraph fSize=10
			Label left "PPR\\u#2"
			SetAxis/A/N=2/E=0 left
			SetAxis/A/R bottom
			ModifyGraph nticks(left)=3
			ModifyViolinPlot trace=wViolinPPRLayers,MarkerColor=(33536,40448,47872),MarkerFilled=1
			ModifyViolinPlot trace=wViolinPPRLayers,FillColor=(61166,61166,61166),CurveExtension=2
			ModifyViolinPlot trace=wViolinPPRLayers,ShowMedian,MedianMarkerStrokeColor=(0,0,0),MarkerSize=5,MedianMarkerSize=5,MedianMarkerThick=1
			ModifyViolinPlot trace=wViolinPPRLayers,MedianMarkerFilled=1,MedianMarkerFillColor=(0,0,0)
			ModifyViolinPlot trace=wViolinPPRLayers,CloseOutline
			// Add sigLines
			CMap_createSigMatrix(wViolinPPRLayers)
			WAVE	sigMatrix
			JT_SigLinesFlipY = 1
			JT_AllBarsSigStars("",sigMatrix)
			JT_SigLinesFlipY = 0
			ModifyGraph swapXY=1
			break
	endswitch
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01PPR across layers\\f00"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"

	// Radial PPR
	WAVE		wCirclePPRMean
	WAVE		wCirclePPRSEM
	WAVE/T		wCircleNs3
	Duplicate/O wCirclePPRMean,wCirclePPRMean2
	wCirclePPRMean2 = wCirclePPRMean+wCirclePPRSEM
	DoWindow/K LayerStatsGraph10
	Display /W=(35,53,572,389) wCirclePPRMean vs wCircleLabel as "Radial PPR"
	DoWindow/C LayerStatsGraph10
	ModifyGraph mode=5
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	SetAxis/A/N=1 left
	SetAxis bottom,0,(Round(CMap_radialEnd/CMap_radialStep)-1)*CMap_radialStep
	AppendToGraph wCirclePPRMean vs wCircleLabel
	ModifyGraph mode(wCirclePPRMean#1)=2
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph offset(wCirclePPRMean#1)={CMap_radialStep/2,0}
	ErrorBars wCirclePPRMean#1 Y,wave=(wCirclePPRSEM,wCirclePPRSEM)
	AppendToGraph wCirclePPRMean2 vs wCircleLabel
	ModifyGraph offset(wCirclePPRMean2)={CMap_radialStep/2,0}
	ModifyGraph toMode(wCirclePPRMean)=-1,mode(wCirclePPRMean2)=3
	ModifyGraph rgb(wCirclePPRMean2)=(0,0,0),textMarker(wCirclePPRMean2)={wCircleNs3,"default",1,0,1,0.00,0.00}
	Label left "PPR\\u#2"
	Label bottom "radius (µm)"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01Radial PPR\\f00"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMap_KillLayerStatsPlotsProc,title="×",fSize=10,font="Arial"
	ModifyGraph margin(left)=48,nticks(left)=3
	
	JT_ArrangeGraphs2("LayerStatsGraph1;LayerStatsGraph2;LayerStatsGraph3;;LayerStatsGraph4;LayerStatsGraph5;LayerStatsGraph6;;LayerStatsGraph9;LayerStatsGraph7;LayerStatsGraph10;",4,5)
	JT_ArrangeGraphs2(";;;;;;;;;LayerStatsGraph8;LayerStatsGraph11",3,5)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the sig matrix for plotting significance hooks

Function CMap_createSigMatrix(sourceMatrix)
	WAVE		sourceMatrix
	
	Variable	nCat = DimSize(sourceMatrix,1)
	Make/O/N=(nCat,nCat) sigMatrix
	sigMatrix = 1
	Variable	i,j
	Variable	pVal
	i = 0
	do
		j = i+1
		do
			Duplicate/O/R=[][i] sourceMatrix,w1
			Duplicate/O/R=[][j] sourceMatrix,w2
			JT_RemoveNaNs(w1)
			JT_RemoveNaNs(w2)
			if ( (numpnts(w1)>2) %& (numpnts(w2)>2) )
				pVal = DoTTest(w1,w2)
				sigMatrix[i][j] = pVal					// No correction for multiple comparison!
			endif
			j += 1
		while(j<nCat)
		i += 1
	while(i<nCat-1)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the sig matrix for plotting significance hooks for connectivity data

Function CMap_createConnSigMatrix(nConnWave,nTestedWave)
	WAVE		nConnWave
	WAVE		nTestedWave
	
	Variable	nCat = numpnts(nTestedWave)
	Make/O/N=(nCat,nCat) sigMatrix
	sigMatrix = 1
	Variable	i,j
	Variable	pVal
	i = 0
	do
		j = i+1
		do
			CMap_Ratio2wave(nConnWave[i],nTestedWave[i])
			WAVE		wOnesAndZeros
			Duplicate/O wOnesAndZeros,w1
			CMap_Ratio2wave(nConnWave[j],nTestedWave[j])
			Duplicate/O wOnesAndZeros,w2
			if ( (numpnts(w1)>3) %& (numpnts(w2)>3) )
				StatsWilcoxonRankTest/Q/TAIL=4 w1,w2
				WAVE		W_WilcoxonTest
				pVal = W_WilcoxonTest[5]
				sigMatrix[i][j] = pVal			// No correction for multiple comparison!
			endif
			j += 1
		while(j<nCat)
		i += 1
	while(i<nCat-1)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Convert ratio to wave with ones and zeros

Function CMap_Ratio2wave(nConn,nTested)
	Variable	nConn,nTested

	Make/O/N=(nConn) theOnes
	theOnes = 1
	Make/O/N=(nTested-nConn) theZeros
	theZeros = 0
	
	Concatenate/NP/O {theOnes,theZeros},wOnesAndZeros
	
End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Kill the layer stats plots

Function CMap_KillLayerStatsPlotsProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMap_KillLayerStatsPlots()
			break
	endswitch

	return 0
End

Function CMap_KillLayerStatsPlots()

	DoWindow/K LayerStatsGraph1
	DoWindow/K LayerStatsGraph2
	DoWindow/K LayerStatsGraph3
	DoWindow/K LayerStatsGraph4
	DoWindow/K LayerStatsGraph5
	DoWindow/K LayerStatsGraph6
	DoWindow/K LayerStatsGraph7
	DoWindow/K LayerStatsGraph8
	DoWindow/K LayerStatsGraph9
	DoWindow/K LayerStatsGraph10
	DoWindow/K LayerStatsGraph11

End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Rotate the coordinates

Function CMap_Rotate(rotAngle,xCoord,yCoord)
	Variable	rotAngle
	
	WAVE		xCoord
	WAVE		yCoord

	Variable	radAngle = rotAngle*pi/180
	Variable	nPoints = numpnts(xCoord)

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
//// Create 3D scatter plot

Function CMap_makeScatter3dProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			CMap_3dConnectivityMap()
			break
	endswitch

	return 0

End

Function CMap_3dConnectivityMap()

	WAVE		CMap_cellX
	WAVE		CMap_cellY
	WAVE		CMap_LayoutStageZ
	WAVE		CMap_LayoutResp
	
	Concatenate/O {CMap_cellX,CMap_cellY,CMap_LayoutStageZ},CMap_XYZ
	Concatenate/O {CMap_LayoutResp,CMap_LayoutResp,CMap_LayoutResp,CMap_LayoutResp},CMap_XYZ_col
	
	CMap_XYZ_col[0][0] = 0
	CMap_XYZ_col[0][1] = 0
	CMap_XYZ_col[0][2] = 0
	CMap_XYZ_col[0][3] = 1
	
	Variable	n = numpnts(CMap_LayoutResp)
	Variable	gray = 0.85
	Variable	i
	i = 1
	do
		if (CMap_LayoutResp[i])
			CMap_XYZ_col[i][0] = 1
			CMap_XYZ_col[i][1] = 0
			CMap_XYZ_col[i][2] = 0
			CMap_XYZ_col[i][3] = 1
		else
			CMap_XYZ_col[i][0] = gray
			CMap_XYZ_col[i][1] = gray
			CMap_XYZ_col[i][2] = gray
			CMap_XYZ_col[i][3] = 1
		endif
		i += 1
	while(i<n)
	
	CMap_createScatter3D()

End

Function CMap_createScatter3D()
	DoWindow/K CMAP_Scatter3D
	NewGizmo/K=1/T="Scatter 3D"/W=(35,53,712,641)
	DoWindow/C CMAP_Scatter3D
	ModifyGizmo startRecMacro=901
	ModifyGizmo scalingOption=63
	AppendToGizmo Scatter=root:CMap_XYZ,name=CMap_Scatter
	ModifyGizmo ModifyObject=CMap_Scatter,objectType=scatter,property={ scatterColorType,1}
	ModifyGizmo ModifyObject=CMap_Scatter,objectType=scatter,property={ markerType,0}
	ModifyGizmo ModifyObject=CMap_Scatter,objectType=scatter,property={ sizeType,0}
	ModifyGizmo ModifyObject=CMap_Scatter,objectType=scatter,property={ rotationType,0}
	ModifyGizmo ModifyObject=CMap_Scatter,objectType=scatter,property={ Shape,2}
	ModifyGizmo ModifyObject=CMap_Scatter,objectType=scatter,property={ size,0.2}
	ModifyGizmo ModifyObject=CMap_Scatter,objectType=scatter,property={ colorWave,root:CMap_XYZ_col}
	AppendToGizmo Axes=boxAxes,name=axes0
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={-1,axisScalingMode,1}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={0,ticks,3}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={1,ticks,3}
	ModifyGizmo ModifyObject=axes0,objectType=Axes,property={2,ticks,3}
	ModifyGizmo modifyObject=axes0,objectType=Axes,property={-1,Clipped,0}
	ModifyGizmo setDisplayList=0, object=CMap_Scatter
	ModifyGizmo setDisplayList=1, object=axes0
	ModifyGizmo autoscaling=1
	ModifyGizmo aspectRatio=1
	ModifyGizmo currentGroupObject=""
	ShowTools
	ModifyGizmo showAxisCue=1
	ModifyGizmo home={0,180,180}
	ModifyGizmo SETQUATERNION={1.000000,0.000000,0.000000,0.000000}
	SetWindow kwTopWin sizeLimit={46,234,inf,inf}
	ModifyGizmo zoomMode = 1
	ModifyGizmo zoomFactor = 0.7
	ModifyGizmo endRecMacro
End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the linear histogram

Function CMap_BinHist()

	WAVE		CMap_LayoutUseAmp

	WaveStats/Q CMap_LayoutUseAmp
	Variable	binSize = 0.2e-3
	Variable	nBins = Round(V_max/binSize)+1
	DoWindow/K LayerStatsGraph7
	JT_MakeHistSpecced("CMap_LayoutUseAmp",0,binSize,nBins,"amplitude (mV)","EPSP histogram")
	DoWindow/C LayerStatsGraph7
	ModifyGraph mrkThick=1
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	ModifyGraph lsize=1
	ModifyGraph fSize=10
	Label bottom "amplitude (mV)\\u#2"
	WaveStats/Q CMap_LayoutUseAmp
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01EPSP histogram\\f00\rn = "+num2str(V_npnts)
	SetDrawLayer UserFront
	SetDrawEnv xcoord= bottom,dash= 11
	DrawLine V_avg,0,V_avg,1
	SetDrawEnv xcoord= bottom,fstyle= 3,textrot= 90,fsize= 9
	SetDrawEnv textxjust= 0, textyjust= 2
	DrawText V_avg,0,"mean"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the log histogram with the logNormal fit

Function CMap_logBinHist()

	WAVE		allUseAmp = CMap_LayoutUseAmp
	
	WaveStats/Q	allUseAmp
	Variable 	nBins
	Variable	div = 1.69
	
	Variable	theMax = V_max*div^2
	
	Variable	minTarget = 0.01e-3
	nBins = Ceil( ln(theMax/minTarget)/ln(div) )
	
	print		"nBins:",nBins
	
	print		"Log min:",theMax/div^nBins*1e3,"mV"
	
	Make/O/N=(nBins) CMM_nonLinBins
	CMM_nonLinBins = theMax/div^p
	Sort CMM_nonLinBins,CMM_nonLinBins
	
	Make/O/N=(nBins) nonLinHist
	Histogram/NLIN=CMM_nonLinBins allUseAmp,nonLinHist

	Variable	TheSum = Sum(nonLinHist)						// Normalize
	nonLinHist *= 100/TheSum
	nonLinHist[numpnts(nonLinHist)] = {0}				// Add a zero bin so that wave numbers match up
	
	CMM_nonLinBins *= 1e3									// Convert to mV

	DoWindow/K LayerStatsGraph7
	Display nonLinHist vs CMM_nonLinBins as "Log EPSP Histogram"
	DoWindow/C LayerStatsGraph7
	ModifyGraph log(bottom)=1
	ModifyGraph mode=5
	ModifyGraph mrkThick=1
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	ModifyGraph lsize=1
	ModifyGraph fSize=10
	SetAxis/A/N=1 left
	Label left,"frequency (%)"
	Label bottom "amplitude (mV)\\u#2"

	K0 = 0;CurveFit/Q/H="1000"/M=2/W=0 LogNormal, nonLinHist/X=CMM_nonLinBins/D
	ModifyGraph lstyle(fit_nonLinHist)=2,lsize(fit_nonLinHist)=2
	ModifyGraph rgb(fit_nonLinHist)=(65535,0,0)//,65535/2)
//	ModifyGraph offset(fit_nonLinHist)={0.5,0}
	
	print "\ty0",K0
	print "\tA",K1
	print "\tx0",K2
	print "\twidth",K3

	WaveStats/Q allUseAmp
	Legend/C/N=text0/J/A=LT/F=0/B=1/X=1.00/Y=0.00 "\\f01EPSP histogram\\f00\rx\B0\M = "+num2str(Round(k2*1e2)/1e2)+"\rσ = "+num2str(Round(k3/sqrt(2)*1e2)/1e2)+"\rmax = "+num2str(Round(V_max*1e5)/1e2)+" mV\rmin = "+num2str(Round(V_min*1e6)/1e3)+" mV\rn = "+num2str(V_npnts)
	SetDrawEnv xcoord= bottom,dash= 11
	DrawLine V_avg*1e3,0,V_avg*1e3,1
	SetDrawEnv xcoord= bottom,fstyle= 3,textrot= 90,fsize= 9
	SetDrawEnv textxjust= 0, textyjust= 2
	DrawText V_avg*1e3,0,"mean"

	ModifyGraph nticks(left)=3,minor(left)=1

	if (Exists("CMap_LineSource")==0)
		print "Run\rCMap_combineAllStoredAwaySynapticResponseData()"
		Abort "Missing wave.  See command history for instructions."
	endif	
	WAVE CMap_LineSource
	WaveStats/Q allUseAmp
	print "Smallest value ",V_min*1e3,"mV comes from entry",V_minloc," which is from line",CMap_LineSource[V_minloc],"in the CMap Parameters table."
	
End

