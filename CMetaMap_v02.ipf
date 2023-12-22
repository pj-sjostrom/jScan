#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3				// Use modern global access method and strict wave access
#pragma DefaultTab={3,20,4}		// Set default tab width in Igor Pro 9 and later
#include <New Polar Graphs>

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CONNECTIVITY META-MAPPER
// by Jesper Sjöström, starting on 2021-11-24
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2021-11-24
//	*	A first functional version
//	*	Make the heatmaps, both symmetric and asymmetric
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2021-11-25
//	*	Adding bar graphs.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2022-01-30
//	*	Heat maps used gaussian blobs with double the diameter, instead of radius. Also made sure diameter
//		matched gaussian blob half-width rather than gaussian blob sigma; this was a minor correction.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2022-05-06
//	*	Heat maps are now divided by the number of postsynaptic cells, to enable fair comparison across postsynaptic
//		cells.
//	*	Heatmap colorscale units are now picked from heatmap itself instead of overriden to mV.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-02-03
//	*	Constrain exponential fit to pass through max value.
//	*	Colorized non-linear histogram.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-02-04
//	*	Added new graph for "Amplitude within column" that is calculated with presynaptic perspective (large n of
//		number of inputs) rather than the postsynaptic perspective (small n of number of cells).
//	*	Added polar histograms, which requires #include <New Polar Graphs>.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-02-05
//	*	Tweaked the polar histograms, which are hard to work with!
//	*	Added popup menu for plotting connectivity data from individual experiments.
//	*	Added popup menu for showing data table from individual experiments.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-02-06
//	*	Added button for showing a data table with all experiments.
//	*	Added popup to select which data the radial analysis relies on (all, within column, within local sphere, 
//		within local cylinder).
//	*	Removed the linear histogram from the standard graphs. To plot it, execute CMM_LinBinHist().
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-03-10
//	*	Added cell-centered heat maps, symmetric as well as asymmetric.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-03-13
//	*	Added distorted heat maps, symmetric as well as asymmetric, to make sure all data points end up in the correct
//		layer etc.
//	*	Fixed bug in local connectivity rate analysis where the postsynaptic (the zeroth) cell was also counted.
//	*	Improved local <100µm analysis for node-degree distribution, path strength, etc
//	*	Added cross-section projections of the heat maps.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-03-15
//	*	Added "Load many folders" function to analyze several categories of data.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-03-22
//	*	Added "Plot all centered" function to show all responses overlaid on top of each other.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-04-26
//	*	Added the "Which response?" popup menu, which enables the user to select which response in a train of three
//		EPSPs that should be analyzed. 'Max Depol' plots the peak depolarization, which for e.g. PC-MC connections
//		translates to the third EPSP but _without_ accounting for temporal summation. The 'default' choice is the
//		first pulse that was deemed to have successful presynaptic spiking (meaning it could be in the 2nd position).
//		Make sure to Re-init and Load folder if upgrading from a previous version of this code.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-05-26
//	*	Added an export for stats feature to be used with R Studio and generalized linear modeling.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	J.Sj., 2023-11-22
//	*	Export for stats feature now includes TPR.
//	*	TPR values are filtered for too small EPSP_1 values the same way as PPR values are filtered. This is done
//		post hoc via a kludge, so potential bug warning, there is a dependency here!
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//	TO-DO AND PENDING BUG FIXES
//	*	{CMM_analyzeLayers} assumes that all layers are indicated.
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


	// Types of source data:
	// (don't forget the underscore!)
	// Resp;cellX;cellY;cellZ;UseAmp;PPR;	-- Connectivity, amplitude, PPR, and XYZ coordinates
	// TPR									-- Triple pulse ratio (mean(E2+E3)/E1)
	// Amp1;Amp2;Amp3;						-- E1, E2, and E3 response position readout
	// MaxDepol;MaxDepolLoc					-- Peak depolarization (not accounting for temporal summation) and its latency in ms
	// LLX;LLY;								-- Layer boundaries
	// LayerLoc,ColumnLoc					-- layer location (zero is layer 1, one is L2/3, etc), is in column?
	// RPercConn;RConn;RCells;RX;			-- Radial connectivity
	// RAmpMean;RAmpSEM;					-- Radial amplitude
	// RPPRMean;RPPRSEM;					-- Radial PPR
	// LPercConn;LConn;LCells;LLabels;		-- Connectivity over layers
	// CLPercConn;CLConn;CLCells;			-- Connectivity in column over layers
	// LAmpMean;LAmpSEM;CLAmpMean;CLAmpSEM;	-- Amplitudes across layers and within column
	// LPPRMean;LPPRSEM;					-- PPR across layers (not just within column)
	// Data;Descr;							-- Data wave
	
	// Experiments found in folder: CMM_ExpList
	// CMM_nExps = ItemsInList(CMM_ExpList)			// Note that number of files and number of experiments need not be identical

	// post-loading created coordinates: 
	// _cellX_cent, _cellY_cent				-- these are soma-centered coordinates
	// _cellX_dist, _cellY_dist				-- these coordinates are distorted to fit fractionally within the average layer thicknesses

menu "Macros"
	"Init Connectivity Meta-Mapper",CMM_init()
	"Graphs to front",CMM_GraphsToFront()
	"Kill graphs",CMM_KillGraphs()
	"Export data for stats in R Studio",CMM_exportForStats()
	"-"
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Combine data to export to Excel for R Studio stats treatment

Function CMM_exportForStats()

	SVAR		CMM_ExpList
	NVAR		CMM_columnWidth
	
	Variable	nExps = itemsInList(CMM_ExpList)
	
	Variable	i,k
	String		currExp
	String		currDate
	Variable	currCell
	Variable	currLayer
	Variable	currAmp
	
	String		currSex
	Variable	currAge
	
	Variable	currMaxDepol
	Variable	currMaxDepolLoc

	Variable	IDcounter = 0
	
	Make/O/N=(0) CMM_Export_PostsynLayer
	Make/O/T/N=(0) CMM_Export_Date
	Make/O/N=(0) CMM_Export_PostSyn
	Make/O/N=(0) CMM_Export_PostCellID
	Make/O/N=(0) CMM_Export_Connected
	Make/O/N=(0) CMM_Export_LayerLoc
	Make/O/N=(0) CMM_Export_EPSPAmpli
	Make/O/N=(0) CMM_Export_SampleID
	Make/O/N=(0) CMM_Export_PPR
	Make/O/N=(0) CMM_Export_TPR
	Make/O/T/N=(0) CMM_Export_Sex
	Make/O/N=(0) CMM_Export_Age

	// MaxDepol;MaxDepolLoc					-- Peak depolarization (not accounting for temporal summation) and its latency in ms
	Make/O/N=(0) CMM_Export_MaxDepol
	Make/O/N=(0) CMM_Export_MaxDepolLoc

	i = 0		// Counting all experiments
	do
		currExp = StringFromList(i,CMM_ExpList)
		WAVE		AmpW = $(currExp+"_UseAmp")
		WAVE		layerW = $(currExp+"_layerLoc")
		WAVE		resp = $(currExp+"_Resp")
		WAVE		xCoord = $(currExp+"_cellX")
		WAVE		PPR = $(currExp+"_PPR")
		WAVE		TPR = $(currExp+"_TPR")
		WAVE	/T	Data = $(currExp+"_Data")
		currDate = currExp[5,12]
		currCell = str2num(currExp[14,15])
		currLayer = layerW[0]
		currSex = Data[7]
		currAge = str2num(Data[4])
		WAVE		MaxDepol = $(currExp+"_MaxDepol")
		WAVE		MaxDepolLoc = $(currExp+"_MaxDepolLoc")
		k = 1		// Counting all cells in each experiments _EXCEPT_ the postsynaptic cell
		do
			if (abs(xCoord[k])<CMM_columnWidth/2)
				CMM_Export_PostsynLayer[numpnts(CMM_Export_PostsynLayer)] = {currLayer}
				CMM_Export_Date[numpnts(CMM_Export_Date)] = {currDate}
				CMM_Export_PostSyn[numpnts(CMM_Export_PostSyn)] = {currCell}
				CMM_Export_PostCellID[numpnts(CMM_Export_PostCellID)] = {i+1}
				CMM_Export_Connected[numpnts(CMM_Export_Connected)] = {resp[k]}
				CMM_Export_LayerLoc[numpnts(CMM_Export_LayerLoc)] = {layerW[k]}
				if (resp[k])
					currAmp = AmpW[k]*1e3
					currMaxDepol = MaxDepol[k]*1e3
					currMaxDepolLoc = MaxDepolLoc[k]
				else
					currAmp = NaN
					currMaxDepol = NaN
					currMaxDepolLoc = NaN
				endif
				CMM_Export_EPSPAmpli[numpnts(CMM_Export_EPSPAmpli)] = {currAmp}
				CMM_Export_MaxDepol[numpnts(CMM_Export_MaxDepol)] = {currMaxDepol}
				CMM_Export_MaxDepolLoc[numpnts(CMM_Export_MaxDepolLoc)] = {currMaxDepolLoc}
				IDcounter += 1
				CMM_Export_SampleID[numpnts(CMM_Export_SampleID)] = {IDcounter}
				CMM_Export_PPR[numpnts(CMM_Export_PPR)] = {PPR[k]}
				CMM_Export_TPR[numpnts(CMM_Export_TPR)] = {TPR[k]}
				CMM_Export_Sex[numpnts(CMM_Export_Sex)] = {currSex}
				CMM_Export_Age[numpnts(CMM_Export_Age)] = {currAge}
			endif
			k += 1
		while(k<numpnts(AmpW))
		i += 1
	while(i<nExps)
	
	DoWindow/K expForStatsTable
	Edit as "Export For Stats Table"
	DoWindow/C expForStatsTable
	AppendToTable CMM_Export_PostsynLayer
	AppendToTable CMM_Export_Date
	AppendToTable CMM_Export_PostSyn
	AppendToTable CMM_Export_PostCellID
	AppendToTable CMM_Export_Connected
	AppendToTable CMM_Export_LayerLoc
	AppendToTable CMM_Export_EPSPAmpli
	AppendToTable CMM_Export_PPR
	AppendToTable CMM_Export_TPR
	AppendToTable CMM_Export_Sex
	AppendToTable CMM_Export_Age
	AppendToTable CMM_Export_SampleID
	AppendToTable CMM_Export_MaxDepol
	AppendToTable CMM_Export_MaxDepolLoc
	ModifyTable title(CMM_Export_PostsynLayer)="Postsyn Layer"
	ModifyTable title(CMM_Export_Date)="Date"
	ModifyTable title(CMM_Export_PostSyn)="Postsyn"
	ModifyTable title(CMM_Export_PostCellID)="Cell ID"
	ModifyTable title(CMM_Export_Connected)="Connected"
	ModifyTable title(CMM_Export_LayerLoc)="Layer Loc"
	ModifyTable title(CMM_Export_EPSPAmpli)="EPSP ampli"
	ModifyTable title(CMM_Export_PPR)="PPR"
	ModifyTable title(CMM_Export_TPR)="TPR"
	ModifyTable title(CMM_Export_Sex)="Sex"
	ModifyTable title(CMM_Export_Age)="Age"
	ModifyTable title(CMM_Export_SampleID)="SampleID"
	ModifyTable title(CMM_Export_MaxDepol)="MaxDepol"
	ModifyTable title(CMM_Export_MaxDepolLoc)="MaxDepolLoc"
	ModifyTable width=100
	ModifyTable width(point)=60
	
	// Kludge for unfiltered TPR
	Variable	n = numpnts(CMM_Export_PPR)
	Variable	countNaNs = 0
	i = 0
	do
		if (JT_isNAN(CMM_Export_PPR[i]))
			CMM_Export_TPR[i] = NaN
			countNaNs += 1
		endif
		i += 1
	while(i<n)
	print "TPR values were filtered for too small EPSP_1 amplitudes as per PPR NaNs, n = "+num2str(countNaNs)+" values removed from TPR."
	
	JT_ArrangeGraphs2("expForStatsTable;",2,2)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Graphs to front

Function CMM_GraphsToFrontProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMM_GraphsToFront()
			break
	endswitch

	return 0
End

Function CMM_GraphsToFront()

	Variable	n = 20
	Variable	i
	i = 0
	do
		DoWindow/F $("CMM_Graph"+num2str(i+1))
		i += 1
	while(i<n)

	DoWindow/F CMM_Graph1_cent
	DoWindow/F CMM_Graph2_cent

	DoWindow/F CMM_Graph1_dist
	DoWindow/F CMM_Graph2_dist
	
	DoWindow/F CMM_CrossSectionXGraph
	DoWindow/F CMM_CrossSectionYGraph

End

Function CMM_KillGraphs()

	Variable	n = 20
	Variable	i
	i = 0
	do
		DoWindow/K $("CMM_Graph"+num2str(i+1))
		i += 1
	while(i<n)

	DoWindow/K CMM_Graph1_cent
	DoWindow/K CMM_Graph2_cent

	DoWindow/K CMM_Graph1_dist
	DoWindow/K CMM_Graph2_dist
	
	DoWindow/K CMM_CrossSectionXGraph
	DoWindow/K CMM_CrossSectionYGraph

End

///////////////////////////////////////////////////////////////
//// Init variables

Function CMM_init()

	print "--- STARTING UP CONNECTIVITY META-MAPPER ---"
	Print date(),time()
	print "Setting up variables..."
	
	// Set up variables
	JT_GlobalVariable("CMM_GraphList",0,"",1)
	JT_GlobalVariable("CMM_PathStr",0,"<empty path>",1)
	JT_GlobalVariable("CMM_ExpList",0,"",1)

	JT_GlobalVariable("CMM_RAT_Str",0,"",1)										// TIFF tags string for recently loaded file
	JT_GlobalVariable("CMM_columnWidth",200,"",0)								// Cortical column width (µm)
	JT_GlobalVariable("CMM_HeatmapGamma",0.5,"",0)								// Heatmap gamma value

	JT_GlobalVariable("CMM_localRadius",100,"",0)								// Define the local radius, to enable comparison with paired recordings (µm)

	JT_GlobalVariable("CMM_plotExpNum",0,"",0)									// Experiment number for popup menu
	JT_GlobalVariable("CMM_plotExpNum_cent",0,"",0)								// Experiment number for popup menu, cell-centered

	Print " "		// JT_GlobalVariable uses printf

	// Set up waves
	print "Setting up waves..."
	Make/T/O/N=(7)	wLayerSourceLabels = {"Layer 1","Layer 2/3","Layer 4","Layer 5","Layer 6","WM","too many lines!"}
	
	Create_CMMPanel()
	DoWindow/F CMMPanel

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make the Connectivity Map Panel

Function Create_CMMPanel()
	
	Variable		ScSc = PanelResolution("")/ScreenResolution

	Variable		Xpos = 560
	Variable		Ypos = 64
	Variable		Width = 480
	Variable		Height = 300+26*2
	
	// If panel already exists, keep it in the same place, please
	DoWindow CMMPanel
	if (V_flag)
		GetWindow CMMPanel, wsize
		xPos = V_left/ScSc
		yPos = V_top/ScSc
		print "Using old panel coordinates:",xPos,yPos
	endif

	Variable		xMargin = 4
	Variable		x = 4
	Variable		y = 4
	
	Variable		xSkip = 32
	Variable		ySkip = 26
	
	Variable		bHeight = 21
	
	Variable		fontSize=12

	DoWindow/K CMMPanel
	NewPanel/K=2/W=(xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc+4*ScSc,yPos*ScSc+Height*ScSc) as "Connectivity Meta-Mapper"
	DoWindow/C CMMPanel
	ModifyPanel/W=CMMpanel fixedSize=1
	
	xSkip = floor((Width-xMargin*2)/4)
	x = xMargin
	Button CMM_LoadAndAnalyze,pos={x,y},size={xSkip-4,bHeight},proc=CMM_LoadFolderProc,title="Load folder",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	SetVariable PathStrSetVar,frame=0,noedit=1,pos={x,y+2},size={xSkip*3-4,bHeight},title=" ",value=CMM_PathStr,limits={0,0,0},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	Button RedoAnalysisButton,pos={x,y},size={xSkip-4,bHeight},proc=CMM_redoAnalysisProc,title="Redo analysis",fsize=fontSize,font="Arial"
	x += xSkip
	PopupMenu whichResponseMode title="Which response?",pos={x,y+2},size={xSkip-4,bHeight},bodyWidth=(xSkip-4)*0.55,mode=1,value="Default;EPSP1;EPSP2;EPSP3;Max Depol;",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/2)
	x = xMargin
	SetVariable GammaSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Gamma",proc=CMM_updateGammaProc,value=CMM_HeatmapGamma,limits={0,Inf,0.1},fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable columnWidthSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Column width (µm)",value=CMM_columnWidth,limits={50,Inf,10},fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button localAnalysisButton,pos={x,y},size={xSkip-4,bHeight},proc=CMM_localAnalysisProc,title="Local analysis",fsize=fontSize,font="Arial"
	x += xSkip
	SetVariable localRadiusSetVar,pos={x,y+3},size={xSkip-4,bHeight},title="Local radius (µm)",value=CMM_localRadius,limits={0,Inf,10},fsize=fontSize,font="Arial"
	x += xSkip
	PopupMenu analysisMode title="Radial plots",pos={x,y+2},size={xSkip-4,bHeight},bodyWidth=(xSkip-4)*0.55,mode=4,value="All data;Within column;Within local sphere;Within local cylinder;",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	SVAR	CMM_ExpList
	PopupMenu ShowSampleExperiment title="Plot one experiment",pos={x,y+2},size={xSkip-4,bHeight},bodyWidth=xSkip-4,proc=CMM_ShowSamplePopProc,mode=0,value=#"CMM_ExpList"
	x += xSkip
	PopupMenu ShowSampleData title="Data table from one experiment",pos={x,y+2},size={xSkip-4,bHeight},bodyWidth=xSkip-4,proc=CMM_SampleDataTablePopProc,mode=0,value=#"CMM_ExpList"
	x += xSkip
	PopupMenu ShowSampleExperiment_cent title="Plot one centered",pos={x,y+2},size={xSkip-4,bHeight},bodyWidth=xSkip-4,proc=CMM_ShowSamplePopProc_cellCentered,mode=0,value=#"CMM_ExpList"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button CMM_LoadManyFolders,pos={x,y},size={xSkip-4,bHeight},proc=CMM_LoadManyFoldersProc,title="Load many folders",fsize=fontSize,font="Arial",fColor=(0,65535,0)
	x += xSkip
	Button AllDataTableButton,pos={x,y},size={xSkip-4,bHeight},proc=CMM_AllDataTableProc,title="All data table",fsize=fontSize,font="Arial"
	x += xSkip
	Button ShowAllDataCenteredButton,pos={x,y},size={xSkip-4,bHeight},proc=CMM_makeConnectivityGraph_allCellCenteredProc,title="Plot all centered",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	xSkip = floor((Width-xMargin*2)/3)
	x = xMargin
	Button GraphsToFrontButton,pos={x,y},size={xSkip-4,bHeight},proc=CMM_GraphsToFrontProc,title="Graphs to front",fsize=fontSize,font="Arial"
	x += xSkip
	Button RedrawPanelButton,pos={x,y},size={xSkip-4,bHeight},proc=CMM_RedrawPanelProc,title="Redraw panel",fsize=fontSize,font="Arial"
	x += xSkip
	Button ReInitButton,pos={x,y},size={xSkip-4,bHeight},proc=CMM_ReInitProc,title="Re-init",fsize=fontSize,font="Arial"
	x += xSkip
	y += ySkip

	MoveWindow/W=CMMPanel xPos*ScSc,yPos*ScSc,xPos*ScSc+Width*ScSc,yPos*ScSc+y*ScSc		// Adjust panel size based on number of controls added to it...

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create all data table

Function CMM_AllDataTableProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMM_CreateAllDataTableProc()
			break
	endswitch

	return 0
End

Function CMM_CreateAllDataTableProc()

	SVAR	CMM_ExpList

	DoWindow/K CMM_AllDataTable
	Edit/K=1/W=(5,53,450,500) as "All data table"
	DoWindow/C CMM_AllDataTable
	ModifyTable format(Point)=1
	Variable	nExps = itemsInList(CMM_ExpList)
	String		expName
	Variable	colWidthDescription = 170
	Variable	colWidthData = 120
	Variable	i
	i = 0
	do
		expName = stringFromList(i,CMM_ExpList)
		if (i==0)
			AppendToTable $(expName+"_Descr")
			ModifyTable width($(expName+"_Descr"))=colWidthDescription
			ModifyTable title($(expName+"_Descr"))="Description"
		endif
		AppendToTable $(expName+"_Data")
		ModifyTable width($(expName+"_Data"))=colWidthData
		ModifyTable title($(expName+"_Data"))=expName
		i += 1
	while(i<nExps)
	
	JT_ArrangeGraphs2("CMM_AllDataTable;",2,2)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Generate data table from one experiment from the popup menu

Function CMM_SampleDataTablePopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			CMM_MakeTheSampleDataTable(popNum,popStr)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function CMM_MakeTheSampleDataTable(expNum,expName)
	Variable	expNum
	String		expName

	print "Data table from ",expName

	DoWindow/K CMM_SampleDataTable
	Edit/K=1/W=(5,53,450,500) $(expName+"_Descr"),$(expName+"_Data") as "Experiment "+num2str(expNum)+": "+expName
	DoWindow/C CMM_SampleDataTable
	ModifyTable format(Point)=1,width($(expName+"_Descr"))=180,width($(expName+"_Data"))=180
	AutoPositionWindow/E/M=0/R=CMMpanel CMM_SampleDataTable

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot one experiment from the popup menu

Function CMM_ShowSamplePopProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			CMM_makeConnectivityGraph(popNum,popStr)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot one experiment

Function CMM_makeConnectivityGraph(expNum,expName)
	Variable	expNum
	String		expName
	
	Variable/G	CMM_plotExpNum = expNum
	
	print "Now plotting",expName
//	print expName+"_cellY",expName+"_cellX",expName+"_Resp",expName+"_UseAmp"
	
	WAVE	cellX = $(expName+"_cellX")
	WAVE	cellY = $(expName+"_cellY")
	WAVE	Resp = $(expName+"_Resp")
	WAVE	UseAmp = $(expName+"_UseAmp")
	WAVE/T	Data = $(expName+"_Data")
	
	Duplicate/O Resp,CMM_LayoutMarkers
	CMM_LayoutMarkers = Resp[p] ? 19 : 8
	CMM_LayoutMarkers[0] = 60
	
	DoWindow/K CMM_SampleGraph
	Display /W=(1391,160,2187,922) $(expName+"_cellY") vs $(expName+"_cellX") as "Experiment "+num2str(expNum)+": "+expName
	DoWindow/C CMM_SampleGraph
	AutoPositionWindow/E/M=1/R=CMMpanel CMM_SampleGraph

	ModifyGraph mode=3
	ModifyGraph marker=19
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph zmrkNum($(expName+"_cellY"))={CMM_LayoutMarkers}
	ModifyGraph mrkThick($(expName+"_cellY"))=1
	ModifyGraph opaque($(expName+"_cellY"))=1									// Fill unconnected with white

	// Add response amplitude colouring
	AppendToGraph $(expName+"_cellY") vs $(expName+"_cellX")
	WaveStats/Q UseAmp
	Variable	maxColVal = round(V_max*1e3/3)*1e-3
	if (maxColVal < 1e-3)
		maxColVal = 1e-3
	endif
	if (0)
		ModifyGraph zColor($(expName+"_cellY")#1)={UseAmp,0,maxColVal,Rainbow,1}
	else
		ModifyGraph zColor($(expName+"_cellY")#1)={UseAmp,0,*,Rainbow,1}
	endif
	ModifyGraph mode($(expName+"_cellY")#1)=3,marker($(expName+"_cellY")#1)=19,mrkThick($(expName+"_cellY")#1)=0
	ModifyGraph mrkThick($(expName+"_cellY")#1)=1
	ModifyGraph opaque($(expName+"_cellY")#1)=1,useMrkStrokeRGB($(expName+"_cellY")#1)=1,mrkStrokeRGB($(expName+"_cellY")#1)=(33536,40448,47872)

	// Special case for postsynaptic cell
	Make/O/N=(1) postY,postX
	postY = cellY[0]
	postX = cellX[0]
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
	doUpdate
	GetAxis/Q bottom
	Variable	xLeft = V_min
	Variable	xRight = V_max
	Variable	yLeft
	Variable	yRight
	Variable	lineSlope,lineOffs

	
	Variable	mapFSize=9
	WAVE		LLX = $(expName+"_LLX")
	WAVE		LLY = $(expName+"_LLY")

	// Add layer labels
	WAVE/T		wLayerSourceLabels
	Variable	nLines = Ceil(numpnts(LLX)/3)
	Variable	i
	if (nLines>0)						// Skip loop if there are no lines stored (probably excessively cautious in CMM)
		i = 0
		do
			SetDrawEnv xcoord= bottom,ycoord= left,textyjust= 2,fname= "Arial",fstyle= 3,fsize= mapFSize
			DrawText LLX[i*3],LLY[i*3],wLayerSourceLabels[i+1]
			if (i==0)
				SetDrawEnv xcoord= bottom,ycoord= left,textyjust= 0,fname= "Arial",fstyle= 3,fsize= mapFSize
				DrawText LLX[0],LLY[0],wLayerSourceLabels[0]
			endif
			i += 1
		while(i<nLines)
	endif

	// Add layer lines
	AppendToGraph $(expName+"_LLY") vs $(expName+"_LLX")
	ModifyGraph lstyle($(expName+"_LLY"))=11,rgb($(expName+"_LLY"))=(0,0,0)
	ReorderTraces $(expName+"_cellY"),{$(expName+"_LLY")}
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
	ColorScale/C/N=text0/A=$(locStr)/X=0.00/Y=0.00 trace=$(expName+"_cellY")#1, heightPct=25, widthPct=3, fsize=10,"\\u#2amplitude (mV)"
	Variable	lSp = 22
	Button JT_WinCloseButton,pos={0,1+lSp*0},size={18,18},proc=JT_WinCloseProc,title="×",fSize=10,font="Arial"
	Button NextButton,pos={0,1+lSp*1},size={18*2,18},proc=CMM_NextPrevExpProc,title="next",fSize=10,font="Arial"
	Button PrevButton,pos={0,1+lSp*2},size={18*2,18},proc=CMM_NextPrevExpProc,title="prev",fSize=10,font="Arial"
	Button DataTableButton,pos={0,1+lSp*3},size={18*2,18},proc=CMM_showDataTableProc,title="data",fSize=10,font="Arial"

	// Add column lines
	SetDrawEnv xcoord= bottom,ycoord= left,fname= "Arial",fstyle= 3,fsize= mapFSize
	SetDrawEnv textxjust= 1,textyjust= 2,ycoord= prel
	DrawText 0,0,"Column"
	NVAR		CMM_columnWidth			// Cortical column width (µm)
	SetDrawLayer UserBack
	SetDrawEnv xcoord= bottom,fillfgc= (61166,61166,61166),linethick= 0.00
	DrawRect -CMM_columnWidth/2,0,CMM_columnWidth/2,1
	SetDrawLayer UserFront	

	String legStr = "\\Z14"
	legStr += expName+"\r"
	legStr += num2str(sum(Resp,1,Inf))+"/"+num2str(numpnts(Resp)-1)+" = "+num2str(round(sum(Resp,1,Inf)/(numpnts(Resp)-1)*100))+"%, "
	WaveStats/Q UseAmp
	legStr += num2str(Round(V_avg*1e3*1e2)/1e2)+" ± "+num2str(Round(V_SEM*1e3*1e2)/1e2)+" mV\r"
	legStr += "Medial to the "+Data[8]
	Legend/C/N=text1/J/F=0/B=1/X=0.00/Y=0.00 legStr
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot one cell-centered experiment from the popup menu

Function CMM_ShowSamplePopProc_cellCentered(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			CMM_makeConnectivityGraph_cellCentered(popNum,popStr)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot one cell-centered experiment

Function CMM_makeConnectivityGraph_cellCentered(expNum,expName)
	Variable	expNum
	String		expName
	
	Variable/G	CMM_plotExpNum_cent = expNum
	
	print "Now plotting",expName
//	print expName+"_cellY",expName+"_cellX",expName+"_Resp",expName+"_UseAmp"
	
	WAVE	cellX = $(expName+"_cellX_cent")
	WAVE	cellY = $(expName+"_cellY_cent")
	WAVE	Resp = $(expName+"_Resp")
	WAVE	UseAmp = $(expName+"_UseAmp")
	WAVE/T	Data = $(expName+"_Data")
	
	Duplicate/O Resp,CMM_LayoutMarkers
	CMM_LayoutMarkers = Resp[p] ? 19 : 8
	CMM_LayoutMarkers[0] = 60
	
	DoWindow/K CMM_SampleGraph_cent
	Display /W=(1391,160,2187,922) $(expName+"_cellY_cent") vs $(expName+"_cellX_cent") as "Centered Experiment "+num2str(expNum)+": "+expName
	DoWindow/C CMM_SampleGraph_cent
	AutoPositionWindow/E/M=1/R=CMMpanel CMM_SampleGraph_cent

	ModifyGraph mode=3
	ModifyGraph marker=19
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph zmrkNum($(expName+"_cellY_cent"))={CMM_LayoutMarkers}
	ModifyGraph mrkThick($(expName+"_cellY_cent"))=1
	ModifyGraph opaque($(expName+"_cellY_cent"))=1									// Fill unconnected with white

	// Add response amplitude colouring
	AppendToGraph $(expName+"_cellY_cent") vs $(expName+"_cellX_cent")
	WaveStats/Q UseAmp
	Variable	maxColVal = round(V_max*1e3/3)*1e-3
	if (maxColVal < 1e-3)
		maxColVal = 1e-3
	endif
	if (0)
		ModifyGraph zColor($(expName+"_cellY_cent")#1)={UseAmp,0,maxColVal,Rainbow,1}
	else
		ModifyGraph zColor($(expName+"_cellY_cent")#1)={UseAmp,0,*,Rainbow,1}
	endif
	ModifyGraph mode($(expName+"_cellY_cent")#1)=3,marker($(expName+"_cellY_cent")#1)=19,mrkThick($(expName+"_cellY_cent")#1)=0
	ModifyGraph mrkThick($(expName+"_cellY_cent")#1)=1
	ModifyGraph opaque($(expName+"_cellY_cent")#1)=1,useMrkStrokeRGB($(expName+"_cellY_cent")#1)=1,mrkStrokeRGB($(expName+"_cellY_cent")#1)=(33536,40448,47872)

	// Special case for postsynaptic cell
	Make/O/N=(1) postY_cent,postX_cent
	postY_cent = 0
	postX_cent = 0
	AppendToGraph postY_cent vs postX_cent
	ModifyGraph rgb(postY_cent)=(0,0,0)
	ModifyGraph rgb(postY_cent)=(65535,65535,65535),useMrkStrokeRGB(postY_cent)=1
	ModifyGraph msize(postY_cent)=8,mrkThick(postY_cent)=1
	ModifyGraph mode(postY_cent)=3,marker(postY_cent)=60
		
	Label Left,"µm"
	Label Bottom,"µm"
	ModifyGraph width={Plan,1,bottom,left}
	SetAxis/A/R/N=1 left
	SetAxis/A/N=1 bottom
	doUpdate
	Variable	mapFSize=9

	GetAxis/Q Bottom
	String locStr = "RB"
	Variable	scaleBarRight = 1
	if (abs(V_min)>abs(V_max))
		locStr = "LB"
		scaleBarRight = 0
	endif
	ColorScale/C/N=text0/A=$(locStr)/X=0.00/Y=0.00 trace=$(expName+"_cellY_cent")#1, heightPct=25, widthPct=3, fsize=10,"\\u#2amplitude (mV)"

	Variable	lSp = 22
	Button JT_WinCloseButton,pos={0,1+lSp*0},size={18,18},proc=JT_WinCloseProc,title="×",fSize=10,font="Arial"
	Button NextButton,pos={0,1+lSp*1},size={18*2,18},proc=CMM_NextPrevExpProc_cent,title="next",fSize=10,font="Arial"
	Button PrevButton,pos={0,1+lSp*2},size={18*2,18},proc=CMM_NextPrevExpProc_cent,title="prev",fSize=10,font="Arial"

	// Add column lines
	SetDrawEnv xcoord= bottom,ycoord= left,fname= "Arial",fstyle= 3,fsize= mapFSize
	SetDrawEnv textxjust= 1,textyjust= 2,ycoord= prel
	DrawText 0,0,"Column"
	NVAR		CMM_columnWidth			// Cortical column width (µm)
	SetDrawLayer UserBack
	SetDrawEnv xcoord= bottom,fillfgc= (61166,61166,61166),linethick= 0.00
	DrawRect -CMM_columnWidth/2,0,CMM_columnWidth/2,1
	SetDrawLayer UserFront	

	String legStr = "\\Z14"
	legStr += expName+"\r"
	legStr += num2str(sum(Resp,1,Inf))+"/"+num2str(numpnts(Resp)-1)+" = "+num2str(round(sum(Resp,1,Inf)/(numpnts(Resp)-1)*100))+"%, "
	WaveStats/Q UseAmp
	legStr += num2str(Round(V_avg*1e3*1e2)/1e2)+" ± "+num2str(Round(V_SEM*1e3*1e2)/1e2)+" mV\r"
	legStr += "Medial to the "+Data[8]
	Legend/C/N=text1/J/F=0/B=1/X=0.00/Y=0.00 legStr
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot _all_ cell-centered experiment

Function CMM_makeConnectivityGraph_allCellCenteredProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR		CMM_plotExpNum		// starts counting at 1, not zero!
	SVAR		CMM_ExpList

	switch( ba.eventCode )
		case 2: // mouse up
			CMM_makeConnectivityGraph_allCellCentered()
			break
	endswitch

	return 0

End

Function CMM_makeConnectivityGraph_allCellCentered()
	
	// allCent_cellX,allCent_cellY,allCent_Resp,allCent_UseAmp	

	WAVE	allCent_cellX
	WAVE	allCent_cellY
	WAVE	allCent_Resp
	WAVE	allCent_UseAmp
	
	Duplicate/O allCent_Resp,CMM_LayoutMarkers
	CMM_LayoutMarkers = allCent_Resp[p] ? 19 : 8
	CMM_LayoutMarkers = JT_isNAN(allCent_Resp[p]) ? NaN : CMM_LayoutMarkers[p]
	
	DoWindow/K CMM_AllGraph_cent
	Display /W=(1391,160,2187,922) allCent_cellY vs allCent_cellX as "All experiments, centered"
	DoWindow/C CMM_AllGraph_cent
	AutoPositionWindow/E/M=1/R=CMMpanel CMM_AllGraph_cent

	ModifyGraph mode=3
	ModifyGraph marker=19
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph zmrkNum(allCent_cellY)={CMM_LayoutMarkers}
	ModifyGraph mrkThick(allCent_cellY)=1
	ModifyGraph opaque(allCent_cellY)=1									// Fill unconnected with white

	// Add response amplitude colouring
	AppendToGraph allCent_cellY vs allCent_cellX
	WaveStats/Q allCent_UseAmp
	Variable	maxColVal = round(V_max*1e3/3)*1e-3
	if (maxColVal < 1e-3)
		maxColVal = 1e-3
	endif
	if (0)
		ModifyGraph zColor(allCent_cellY#1)={allCent_UseAmp,0,maxColVal,Rainbow,1}
	else
		ModifyGraph zColor(allCent_cellY#1)={allCent_UseAmp,0,*,Rainbow,1}
	endif
	ModifyGraph mode(allCent_cellY#1)=3,marker(allCent_cellY#1)=19,mrkThick(allCent_cellY#1)=0
	ModifyGraph mrkThick(allCent_cellY#1)=1
	ModifyGraph opaque(allCent_cellY#1)=1,useMrkStrokeRGB(allCent_cellY#1)=1,mrkStrokeRGB(allCent_cellY#1)=(33536,40448,47872)

	// Special case for postsynaptic cell
	Make/O/N=(1) postY_cent,postX_cent
	postY_cent = 0
	postX_cent = 0
	AppendToGraph postY_cent vs postX_cent
	ModifyGraph rgb(postY_cent)=(0,0,0)
	ModifyGraph rgb(postY_cent)=(65535,65535,65535),useMrkStrokeRGB(postY_cent)=1
	ModifyGraph msize(postY_cent)=8,mrkThick(postY_cent)=1
	ModifyGraph mode(postY_cent)=3,marker(postY_cent)=60
		
	Label Left,"µm"
	Label Bottom,"µm"
	ModifyGraph width={Plan,1,bottom,left}
	SetAxis/A/R/N=1 left
	SetAxis/A/N=1 bottom
	doUpdate
	Variable	mapFSize=9

	GetAxis/Q Bottom
	String locStr = "RB"
	Variable	scaleBarRight = 1
	if (abs(V_min)>abs(V_max))
		locStr = "LB"
		scaleBarRight = 0
	endif
	ColorScale/C/N=text0/A=$(locStr)/X=0.00/Y=0.00 trace=allCent_cellY#1, heightPct=25, widthPct=3, fsize=10,"\\u#2amplitude (mV)"

	Variable	lSp = 22
	Button JT_WinCloseButton,pos={0,1+lSp*0},size={18,18},proc=JT_WinCloseProc,title="×",fSize=10,font="Arial"

	// Add column lines
	SetDrawEnv xcoord= bottom,ycoord= left,fname= "Arial",fstyle= 3,fsize= mapFSize
	SetDrawEnv textxjust= 1,textyjust= 2,ycoord= prel
	DrawText 0,0,"Column"
	NVAR		CMM_columnWidth			// Cortical column width (µm)
	SetDrawLayer UserBack
	SetDrawEnv xcoord= bottom,fillfgc= (61166,61166,61166),linethick= 0.00
	DrawRect -CMM_columnWidth/2,0,CMM_columnWidth/2,1
	SetDrawLayer UserFront	

	SVAR	CMM_ExpList
	Variable	nExp = ItemsInList(CMM_ExpList)
	String legStr = "\\Z14"
	allCent_Resp = allCent_Resp[p] < 0 ? NaN : allCent_Resp[p]	// All those postsynaptic cells are -1, so remove them for stats purposes
	WaveStats/Q allCent_Resp
	Variable nConn = V_Sum
	legStr += num2str(nConn)+"/"+num2str(numpnts(allCent_Resp)-nExp)+" = "+num2str(round(nConn/(numpnts(allCent_Resp)-nExp)*100))+"%\r"
	WaveStats/Q allCent_UseAmp
	legStr += num2str(Round(V_avg*1e3*1e2)/1e2)+" ± "+num2str(Round(V_SEM*1e3*1e2)/1e2)+" mV\r"
	legStr += "Median: "+num2str(median(allCent_UseAmp)*1e3)+" mV"
//	legStr += "Medial to the left"
	Legend/C/N=text1/J/F=0/B=1/X=0.00/Y=0.00 legStr
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Show data table for experiment at hand

Function CMM_showDataTableProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR		CMM_plotExpNum		// starts counting at 1, not zero!
	SVAR		CMM_ExpList

	switch( ba.eventCode )
		case 2: // mouse up
			CMM_MakeTheSampleDataTable(CMM_plotExpNum,stringFromList(CMM_plotExpNum-1,CMM_ExpList))
			AutoPositionWindow/E/M=0/R=CMM_SampleGraph CMM_SampleDataTable
			break
	endswitch

	return 0

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Go to next or previous experiment

Function CMM_NextPrevExpProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR		CMM_plotExpNum		// starts counting at 1, not zero!
	SVAR		CMM_ExpList

	switch( ba.eventCode )
		case 2: // mouse up
			if (stringmatch(ba.ctrlName,"NextButton"))
				CMM_plotExpNum += 1
			else
				CMM_plotExpNum -= 1
			endif
			if (CMM_plotExpNum<1)
				CMM_plotExpNum = 1
			endif
			if (CMM_plotExpNum>ItemsInList(CMM_ExpList))
				CMM_plotExpNum = ItemsInList(CMM_ExpList)
			endif
			CMM_makeConnectivityGraph(CMM_plotExpNum,stringFromList(CMM_plotExpNum-1,CMM_ExpList))
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Go to next or previous experiment, cell-centered

Function CMM_NextPrevExpProc_cent(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	NVAR		CMM_plotExpNum_cent		// starts counting at 1, not zero!
	SVAR		CMM_ExpList

	switch( ba.eventCode )
		case 2: // mouse up
			if (stringmatch(ba.ctrlName,"NextButton"))
				CMM_plotExpNum_cent += 1
			else
				CMM_plotExpNum_cent -= 1
			endif
			if (CMM_plotExpNum_cent<1)
				CMM_plotExpNum_cent = 1
			endif
			if (CMM_plotExpNum_cent>ItemsInList(CMM_ExpList))
				CMM_plotExpNum_cent = ItemsInList(CMM_ExpList)
			endif
			CMM_makeConnectivityGraph_cellCentered(CMM_plotExpNum_cent,stringFromList(CMM_plotExpNum_cent-1,CMM_ExpList))
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Reinit

Function CMM_ReInitProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Print "--- REINITIATING CMM ---"
			Print "Note that any checkbox values are reset..."
			CMM_init()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Redraw CMM panel

Function CMM_RedrawPanelProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			Create_CMMPanel()
			break
	endswitch

	return 0
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Load and analyze MANY folders

Function CMM_LoadManyFoldersProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMM_doLoadManyFolders()
			DoWindow/F CMMpanel
			break
	endswitch

	return 0
End

Function CMM_doLoadManyFolders()

	CMM_SetSourcePath()
	
	PathInfo CMM_sourcePath
	String	sourcePathStr = S_path
	String	currPathStr
	print "Looking in "+sourcePathStr

	String		folderList = IndexedDir(CMM_sourcePath,-1,0)
	Variable	nFolders = ItemsInList(folderList)
	print	"Found ",nFolders," folders:"
	print "\t"+folderList
	Variable indexToOld = WhichListItem("old",folderList,";",0,0)	// Case-insensitive search
	if (indexToOld>-1)
		folderList = RemoveListItem(indexToOld,folderList)
		print "Found a folder named \"Old\" so this was removed and won't be analyzed."
		nFolders = ItemsInList(folderList)	// Only load relevant folders
		print	"Updated number of folders:",nFolders
	endif

	String		fList
	Variable	nFiles
	String		currFile,currExp
	Make/O/T/N=(nFolders)	wExpList,wFolders	// List of files for each folder
	wExpList = ""
	wFolders = ""
	Make/O/N=(nFolders)	wNs,wAgeMean,wAgeSEM,wNConnected,wNTested,wConnRateMean,wConnRateSEM
	wNs = NaN
	wNConnected = 0
	wNTested = 0
	print	"Found ",nFiles," files."
	Make/O/N=(0) allAges,allNConnnected,allNTested

	Variable	i,j
	i = 0
	do
		currPathStr = sourcePathStr+StringFromList(i,folderList)
		print currPathStr
		NewPath/O/Q currFolder,currPathStr
		PathInfo currFolder
		if (V_flag)
			print "\tEXISTS"
		else
			print "The folder "+currPathStr+" does not exist!"
			Abort "The folder "+currPathStr+" does not exist!"
		endif
		wFolders[i] = StringFromList(i,folderList)
		fList = IndexedFile(currFolder,-1,"????")
		nFiles = ItemsInList(fList)
		wNs[i] = nFiles
		// Load files
		Make/O/N=(0) workWave1,workWave2,workWave3,workWave4
		Print "Loading files"
		j = 0
		do
			currFile = StringFromList(j,fList)
			if (!(StringMatch(currFile[0,4],"CMap_")))
				print "Skipping presumed system file",currFile
			else
				LoadWave/O/P=currFolder/Q/T currFile
				print "\tLoaded "+num2str(V_flag)+" files from \""+currFile+"\""
				currExp = currFile[0,StrLen(currFile)-1-4]
				wExpList[i] += currExp+";"
				WAVE	/T	Data = $(currExp+"_Data")
				// Age
				allAges[numpnts(allAges)] = {str2num(Data[4])}
				workWave1[numpnts(workWave1)] = {str2num(Data[4])}
				// Connectivity
				WAVE		Resp = $(currExp+"_Resp")
				allNConnnected[numpnts(allNConnnected)] = {sum(Resp,1,Inf)}		// Postsynaptic cell is index zero, so ignore!
				allNTested[numpnts(allNTested)] = {numpnts(Resp)-1}				// Postsynaptic cell is index zero, so ignore!
				workWave2[numpnts(workWave2)] = {sum(Resp,1,Inf)}
				workWave3[numpnts(workWave3)] = {numpnts(Resp)-1}
				workWave4[numpnts(workWave4)] = {sum(Resp,1,Inf)/(numpnts(Resp)-1)*100}
			endif
			j += 1
		while(j<nFiles)
		// Age
		WaveStats/Q workWave1
		wAgeMean[i] = V_avg
		wAgeSEM[i] = V_SEM
		// Connectivity
		wNConnected[i] = Sum(workWave2)
		wNTested[i] = Sum(workWave3)
		WaveStats/Q workWave4
		wConnRateMean[i] = V_avg
		wConnRateSEM[i] = V_SEM
		i += 1
	while(i<nFolders)

	doWindow/K CMM_megaTable
	Edit/K=1 wFolders,wExpList,wNs,wAgeMean,wAgeSEM,wConnRateMean,wConnRateSEM,wNConnected,wNTested as "All experiments in all folders"
	doWindow/C CMM_megaTable
	JT_ArrangeGraphs2("CMM_megaTable;",3,2)
	WaveStats/Q allAges
	print "Ages: from "+num2str(V_min)+" to "+num2str(V_max)+", µ ± SDev = "+num2str(V_avg)+" ± "+num2str(V_SEM)+", median = "+num2str(Median(allAges))+", n = "+num2str(V_npnts)
	print "Total nConnections:",sum(allNConnnected)
	print "Total nTested:",sum(allNTested)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Load and analyze

Function CMM_LoadFolderProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CMM_doLoadFolder()
			DoWindow/F CMMpanel
			break
	endswitch

	return 0
End

Function CMM_doLoadFolder()

	CMM_SetSourcePath()

	SVAR		CMM_ExpList
	CMM_ExpList = ""

	String		fList = IndexedFile(CMM_sourcePath,-1,"????")
	Variable	nFiles = ItemsInList(fList)
	print	"Found ",nFiles," files."

	// Load files
	Print "Loading files"
	String		currFile
	Variable 	i = 0
	do
		currFile = StringFromList(i,fList)
		if (!(StringMatch(currFile[0,4],"CMap_")))
			print "Skipping presumed system file",currFile
		else
			LoadWave/O/P=CMM_sourcePath/Q/T currFile
			print "\tLoaded "+num2str(V_flag)+" files from \""+currFile+"\""
			CMM_ExpList += currFile[0,StrLen(currFile)-1-4]+";"
		endif
		i += 1
	while(i<nFiles)
	
	Variable endOfName = StrLen(currFile)-1-4+2

	String		currWave
	String/G	CMM_sourceWaveList = ""
	Variable	n = itemsInlist(S_waveNames)
	i = 0
	do
		currWave = stringFromList(i,S_waveNames)
		CMM_sourceWaveList += currWave[endOfName,strlen(currWave)-1]+";"
		i += 1
	while (i<n)
	
	print "Source wave list:"
	print CMM_sourceWaveList
	
	print "Experiments found in folder:"
	print CMM_ExpList
	
	Variable/G	CMM_nExps = ItemsInList(CMM_ExpList)	// Note that number of files and number of experiments need not be identical
	
	CMM_storeAwayUseAmp(CMM_ExpList)						// This stores away the default amplitude values so that they can be replaced with the "Which response?" popup setting and then restored.
	
	CMM_analyzeFolder()

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get the y-axis crossing point (the offset) of a line

Function CMM_getLineOffset(x1,y1,x2,y2)
	Variable	x1,y1,x2,y2			// line
	
	Variable	offset = y1-CMM_getLineSlope(x1,y1,x2,y2)*x1
	
	Return		offset

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Get the slope of a line

Function CMM_getLineSlope(x1,y1,x2,y2)
	Variable	x1,y1,x2,y2			// line
	
	Variable	slope = (y2-y1)/(x2-x1)
	
	Return		slope

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Is this coordinate above the line?
//// NB! Origin (0,0) is in the top left corner

Function CMM_AboveLine(x0,y0,x1,y1,x2,y2)
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

Function CMM_BelowLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0				// point to be tested
	Variable	x1,y1,x2,y2			// line

	Return		(!(CMM_AboveLine(x0,y0,x1,y1,x2,y2)))

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Is this coordinate to the right of the line?
//// NB! Origin (0,0) is in the top left corner

Function CMM_RightOfLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0				// point to be tested
	Variable	x1,y1,x2,y2			// line

	// Swap x and y around
	Return		(CMM_BelowLine(y0,x0,y1,x1,y2,x2))

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Is this coordinate to the left of the line?
//// NB! Origin (0,0) is in the top left corner

Function CMM_LeftOfLine(x0,y0,x1,y1,x2,y2)
	Variable	x0,y0				// point to be tested
	Variable	x1,y1,x2,y2			// line

	// Swap x and y around
	Return		(CMM_AboveLine(y0,x0,y1,x1,y2,x2))

End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Calculate the VERTICAL distance between a coordinate and a line

Function CMM_VerticalDistToLine(xVal,yVal,x1,y1,x2,y2)
	Variable	xVal,yVal
	Variable	x1,y1,x2,y2			// line
	
	// y = k*x + m
	Variable	vDist = abs( CMM_getLineSlope(x1,y1,x2,y2)*xVal + CMM_getLineOffset(x1,y1,x2,y2) - yVal )
	
	Return		vDist

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Calculate the distance between a coordinate and a line

Function CMM_DistToLine(x0,y0,x1,y1,x2,y2)
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
//// Create plots based on Local analysis

Function CMM_makeLocalPlots()

	NVAR		CMM_localRadius

	Variable	topMargin = 24
	Variable	fontSize = 10

	WAVE		localConnectivity,localAmpMean,localPathStrength

	doWindow/K localGraph1
	Display /W=(70,504,490,849) as "Local EPSP amplitude"
	doWindow/C localGraph1
	AppendViolinPlot localAmpMean
	ModifyGraph mode=4
	ModifyGraph nticks(left)=3
	ModifyGraph minor(left)=1
	ModifyGraph noLabel(bottom)=2
	ModifyGraph axThick(bottom)=0
	Label left "mean EPSP (mV)"
	SetAxis/A/E=1 left
	ModifyViolinPlot trace=localAmpMean,ShowMedian,MedianMarkerSize=6,MedianMarkerColor=(0,0,0)
	ModifyViolinPlot trace=localAmpMean,MarkerSize=6
	ModifyGraph margin(top)=topMargin
	SetDrawEnv textxjust= 1,fstyle= 1,fsize= fontSize
	DrawText 0.5,0,"EPSP amplitude <"+num2str(CMM_localRadius)+" µm"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMM_WinCloseLocalProc,title="×",fSize=10,font="Arial"

	doWindow/K localGraph2
	Display /W=(498,527,919,842) as "Local connectivity"
	doWindow/C localGraph2
	AppendViolinPlot localConnectivity
	ModifyGraph mode=4
	ModifyGraph nticks(left)=3
	ModifyGraph minor(left)=1
	ModifyGraph noLabel(bottom)=2
	ModifyGraph axThick(bottom)=0
	Label left "connectivity (%)"
	SetAxis/A/E=1 left
	ModifyViolinPlot trace=localConnectivity,ShowMedian,MedianMarkerSize=6,MedianMarkerColor=(0,0,0)
	ModifyViolinPlot trace=localConnectivity,MarkerSize=6
	ModifyGraph margin(top)=topMargin
	SetDrawEnv textxjust= 1,fstyle= 1,fsize= fontSize
	DrawText 0.5,0,"Connectivity <"+num2str(CMM_localRadius)+" µm"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMM_WinCloseLocalProc,title="×",fSize=10,font="Arial"

	doWindow/K localGraph3
	Display /W=(821,557,1251,917) as "Local path strength"
	doWindow/C localGraph3
	AppendViolinPlot localPathStrength
	ModifyGraph mode=4
	ModifyGraph nticks(left)=3
	ModifyGraph minor(left)=1
	ModifyGraph noLabel(bottom)=2
	ModifyGraph axThick(bottom)=0
	Label left "path strength (%mV)"
	SetAxis/A/E=1 left
	ModifyViolinPlot trace=localPathStrength,ShowMedian,MedianMarkerSize=6,MedianMarkerColor=(0,0,0)
	ModifyViolinPlot trace=localPathStrength,MarkerSize=6
	ModifyGraph margin(top)=topMargin
	SetDrawEnv textxjust= 1,fstyle= 1,fsize= fontSize
	DrawText 0.5,0,"Path strength <"+num2str(CMM_localRadius)+" µm"
	Button JT_WinCloseButton,pos={0,1},size={18,18},proc=CMM_WinCloseLocalProc,title="×",fSize=10,font="Arial"

	JT_ArrangeGraphs2(";localGraph1;;;localGraph2;;;localGraph3;",3,10)

End

Function CMM_WinCloseLocalProc(ctrlName) : ButtonControl
	String		ctrlName

	doWindow/K LocalAnalysisDataTable
	doWindow/K localGraph1
	doWindow/K localGraph2
	doWindow/K localGraph3

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Based on Local analysis, create a data table with findings

Function CMM_doLocalDataTable()

	WAVE		localConnected,localTested,localConnectivity,localAmpMean,localAmpSEM,localPathStrength
	WAVE/T		ExpListAsWave

	doWindow/K LocalAnalysisDataTable
	Edit/K=1/W=(5,53,840,596) ExpListAsWave,localConnected,localTested,localConnectivity,localAmpMean,localAmpSEM,localPathStrength as "Local Analysis Data Table"
	doWindow/C LocalAnalysisDataTable
	ModifyTable format(Point)=1,width(ExpListAsWave)=165,width(localConnected)=99,width(localTested)=76
	ModifyTable width(localConnectivity)=106,width(localAmpMean)=95,width(localAmpSEM)=95,width(localPathStrength)=100
	
	JT_ArrangeGraphs2("LocalAnalysisDataTable;",3,3)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Local analysis, to be compared to paired recordings

Function CMM_localAnalysisProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			print "--- LOCAL ANALYSIS ---"
			print date(),time()
			CMM_doLocalAnalysis()
			CMM_doLocalDataTable()
			CMM_makeLocalPlots()
			break
	endswitch

	return 0
End

Function/S CMM_doLocalAnalysis()

	NVAR		CMM_nExps
	SVAR		CMM_ExpList
	
	NVAR		CMM_localRadius

	print "Within "+num2str(CMM_localRadius)+" µm:"

	// Local connectivity and EPSP amplitude
	String		currExp
	Variable	nExps = itemsInList(CMM_ExpList)
	Variable	i,j,k
	
	Variable	postX
	Variable	postY
	
	Variable	nConnected
	Variable	nTested
	
	Variable	nConnectedTot = 0
	Variable	nTestedTot = 0
	
	Make/O/N=(0) workWave2,workWave3,workWave4,workWave5
	Make/O/N=(nExps) localConnected,localTested,localConnectivity,localAmpMean,localAmpSEM,localPathStrength
	Make/O/T/N=(nExps) ExpListAsWave
	i = 0
	do
		currExp = StringFromList(i,CMM_ExpList)
		WAVE		wx = $(currExp+"_cellX")
		WAVE		wy = $(currExp+"_cellY")
		WAVE		amp = $(currExp+"_UseAmp")
		WAVE		resp = $(currExp+"_Resp")
		
		Duplicate/O wx,tempX
		Duplicate/O	wy,tempY,distR
		
		postX = wx[0]
		postY = wy[0]
		
		tempX -= postX
		tempY -= postY
		
		distR = sqrt(tempX^2+tempY^2)			// This is the local cylinder, not the local sphere... should this be fixed?
		
		nConnected = 0
		nTested = 0
		
		Make/O/N=(0) workWave
		
		j = 1									// Skip postsynaptic cell
		do
			if (distR[j] < CMM_localRadius)		// presyn candidate cell is within range, so should be counted
				nTested += 1
				nTestedTot += 1
				workWave5[numpnts(workWave5)] = {i+1}
				if (resp[j])
					nConnected += 1
					nConnectedTot += 1
					workWave[numpnts(workWave)] = {amp[j]}
					workWave2[numpnts(workWave2)] = {amp[j]}
					workWave3[numpnts(workWave3)] = {1}
					workWave4[numpnts(workWave4)] = {amp[j]}
				else
					workWave3[numpnts(workWave3)] = {0}
					workWave4[numpnts(workWave4)] = {NaN}
				endif
			endif
			j += 1
		while(j<numpnts(distR))
		WaveStats/Q/Z workWave
		print "\t"+currExp+" | "+num2str(nConnected)+"/"+num2str(nTested)+" = "+num2str(nConnected/nTested*100)+"%\t | "+num2str(V_avg*1e3)+" ± "+num2str(V_SEM*1e3)+" mV"
		localConnected[i] = nConnected
		localTested[i] = nTested
		localConnectivity[i] = nConnected/nTested*100
		localAmpMean[i] = V_avg*1e3
		localAmpSEM[i] = V_SEM*1e3
		ExpListAsWave[i] = currExp
		localPathStrength[i] = localConnectivity[i]*localAmpMean[i]
		i += 1
	while(i<nExps)

	print "Overall connectivity: "+num2str(nConnectedTot)+"/"+num2str(nTestedTot)+" = "+num2str(nConnectedTot/nTestedTot*100)+"%"
	WaveStats/Q/Z workWave2
	print "Overall EPSP amplitude: "+num2str(V_avg*1e3)+" ± "+num2str(V_SEM*1e3)+" mV"
	print "Range:",V_min*1e3,"to",V_max*1e3,"mV"
	print "Median:",median(workWave2)*1e3,"mV"
	
	print "For cross-category stats, the individual data points were exported as \"localAmplitudes\" and \"localConnectivity\","
	print "as well as \"localAmpWithNaNs\", while \"localCellID\" provides cell identity, counting from 1 and up."
	
	Duplicate/O workWave2,localAmplitudes
	Duplicate/O workWave3,localConnectivity
	Duplicate/O workWave4,localAmpWithNaNs
	Duplicate/O workWave5,localCellID
	
	String	localStatsStr = ""
	localStatsStr += "\\f05<"+num2str(CMM_localRadius)+" µm:\\f01\r"+num2str(nConnectedTot)+"/"+num2str(nTestedTot)+" = "+num2str(Round(nConnectedTot/nTestedTot*1000)/10)+"%\r"
	localStatsStr += num2str(Round(V_avg*1e3*100)/100)+" ± "+num2str(Round(V_SEM*1e3*100)/100)+" mV"
	
	Return localStatsStr

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Redo the analysis

Function CMM_redoAnalysisProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			print "--- REDOING ANALYSIS ---"
			print date(),time()
			CMM_analyzeFolder()
			break
	endswitch

	return 0
End

Function CMM_analyzeFolder()

	NVAR		CMM_nExps
	SVAR		CMM_ExpList
	
	//// Pick the selected response
	CMM_OverwriteUseAmp(CMM_ExpList)
	
	//// Analyze layers
	CMM_analyzeLayers(CMM_ExpList)				// Find the average layer boundaries

	//// Create cell-centered coordinates
	CMM_createCellCenteredCoords(CMM_ExpList)
	
	//// Create radial coordinates
	CMM_createRadialCoords(CMM_ExpList)
	
	//// Create distorted coordinates
	CMM_createDistortedCoordinates(CMM_ExpList)

	//// Find min and max coordinates
	CMM_findMinAndMaxCoordinates(CMM_ExpList)

	//// Find average postsynaptic cell location
	CMM_findPostCellLoc(CMM_ExpList)

	//// Create soma-centered layer boundaries
	WAVE		wLayerOffs
	WAVE		CMM_postY_mean
	Variable	postY_mean = CMM_postY_mean[0]
	Duplicate/O	wLayerOffs,wLayerOffs_cent
	wLayerOffs_cent = wLayerOffs-postY_mean

	//// Produce averaged heatmaps (one asymmetric and one symmetric, for both absolute and cell-centered coordinates)
	CMM_CreateMatrices()
	String		currExp
	Variable	nExps = itemsInList(CMM_ExpList)
	Variable	i,j,k
	Variable	xSign
	i = 0
	do
		currExp = StringFromList(i,CMM_ExpList)
		WAVE		wx = $(currExp+"_cellX")
		WAVE		wy = $(currExp+"_cellY")
		WAVE		wx_cent = $(currExp+"_cellX_cent")
		WAVE		wy_cent = $(currExp+"_cellY_cent")
		WAVE		wx_dist = $(currExp+"_cellX_dist")
		WAVE		wy_dist = $(currExp+"_cellY_dist")
		WAVE		amp = $(currExp+"_UseAmp")
		WAVE		resp = $(currExp+"_Resp")
		WAVE	/T	data = $(currExp+"_data")
		if (stringMatch(data[8],"Right"))		// Medial surface to the right means the data has to be flipped over along the x-axis
			xSign = -1
		else
			xSign = 1
		endif
		// Absolute coordinates
		Duplicate/O wx,wTemp
		wTemp *= xSign
		CMM_AddToMatrices(wTemp,wy,amp,resp,"")
		// Cell-centered coordinates
		Duplicate/O wx_cent,wTemp
		wTemp *= xSign
		CMM_AddToMatrices(wTemp,wy_cent,amp,resp,"_cent")
		// Distorted coordinates
		Duplicate/O wx_dist,wTemp
		wTemp *= xSign
		CMM_AddToMatrices(wTemp,wy_dist,amp,resp,"_dist")
		i += 1
	while(i<nExps)
	WAVE		CMM_asymmMatrix
	WAVE		CMM_symmMatrix
	WAVE		CMM_asymmMatrix_cent
	WAVE		CMM_symmMatrix_cent
	WAVE		CMM_asymmMatrix_dist
	WAVE		CMM_symmMatrix_dist
	NVAR		CMM_HeatmapGamma
	
	// Heatmaps should be averages across cells (JSj, 6 May 2022)
	CMM_asymmMatrix /= nExps
	CMM_symmMatrix /= nExps
	CMM_symmMatrix /= 2				// Divided by two, since each heatmap is used twice?
	CMM_asymmMatrix_cent /= nExps
	CMM_symmMatrix_cent /= nExps
	CMM_symmMatrix_cent /= 2		// Divided by two, since each heatmap is used twice?
	CMM_asymmMatrix_dist /= nExps
	CMM_symmMatrix_dist /= nExps
	CMM_symmMatrix_dist /= 2		// Divided by two, since each heatmap is used twice?
	
	CMM_makeGammaCorrectedLUT(CMM_HeatmapGamma)
	//// MAPS IN ABSOLUTE COORDINATES
	// Asymmetric heatmap
	DoWindow/K CMM_Graph1
	NewImage/S=0 CMM_asymmMatrix
	JT_NameWin("CMM_Graph1","Asymmetric Connectivity Heatmap")
	ModifyImage CMM_asymmMatrix ctab= {*,*,CMM_LUT,0}
	ColorScale/C/N=text0/A=RB/X=10.00/Y=5.00/B=(0,0,0)/G=(65535,65535,65535) image=CMM_asymmMatrix, heightPct=25, widthPct=3, fsize=10,"amplitude (\\U)"
	ModifyGraph width={Plan,1,top,left}
	CMM_addScaleBar()
	CMM_addLayerLines()
	CMM_addColumnLines()
	CMM_addPostCell()
	CMM_addCircleAroundSoma()
	CMM_addTheNs(CMM_ExpList)
	// Indicate where medial side is
	Variable	arrowLen = 10/100
	Variable	yPos = 0.01
	Variable	xPos = 0.9
	SetDrawLayer UserFront
	SetDrawEnv linethick= 2,linefgc= (65535,65535,65535),fillpat= 0,xcoord= prel,ycoord= prel,arrow= 2,arrowfat=0.75
	DrawLine xPos-arrowLen/2,yPos,xPos+arrowLen/2,yPos
	SetDrawEnv textxjust= 1,textyjust= 2,fname= "Arial",fstyle= 3, textrgb= (65535,65535,65535),fsize=10
	yPos += 0.01
	DrawText xPos,yPos, "Medial"
	// Symmetric heatmap
	DoWindow/K CMM_Graph2
	NewImage/S=0 CMM_symmMatrix
	JT_NameWin("CMM_Graph2","Symmetric Connectivity Heatmap")
	ModifyImage CMM_symmMatrix ctab= {*,*,CMM_LUT,0}
	ColorScale/C/N=text0/A=RB/X=10.00/Y=5.00/B=(0,0,0)/G=(65535,65535,65535) image=CMM_symmMatrix, heightPct=25, widthPct=3, fsize=10,"amplitude (\\U)"
	ModifyGraph width={Plan,1,top,left}
	CMM_addScaleBar()
	CMM_addLayerLines()
	CMM_addColumnLines()
	CMM_addPostCell()
	CMM_addCircleAroundSoma()
	CMM_addTheNs(CMM_ExpList)
	
	//// MAPS IN CELL-CENTERED COORDINATES
	// Asymmetric heatmap
	DoWindow/K CMM_Graph1_cent
	NewImage/S=0 CMM_asymmMatrix_cent
	JT_NameWin("CMM_Graph1_cent","Centered Asymmetric Connectivity Heatmap")
	ModifyImage CMM_asymmMatrix_cent ctab= {*,*,CMM_LUT,0}
	ColorScale/C/N=text0/A=RB/X=10.00/Y=5.00/B=(0,0,0)/G=(65535,65535,65535) image=CMM_asymmMatrix_cent, heightPct=25, widthPct=3, fsize=10,"amplitude (\\U)"
	ModifyGraph width={Plan,1,top,left}
	CMM_addScaleBar()
	CMM_addLayerLines_cent()
	CMM_addColumnLines()
	CMM_addPostCell_cent()
	CMM_addCircleAroundSoma_cent()
	CMM_addTheNs(CMM_ExpList)
	// Indicate where medial side is
	SetDrawLayer UserFront
	SetDrawEnv linethick= 2,linefgc= (65535,65535,65535),fillpat= 0,xcoord= prel,ycoord= prel,arrow= 2,arrowfat=0.75
	DrawLine xPos-arrowLen/2,yPos,xPos+arrowLen/2,yPos
	SetDrawEnv textxjust= 1,textyjust= 2,fname= "Arial",fstyle= 3, textrgb= (65535,65535,65535),fsize=10
	yPos += 0.01
	DrawText xPos,yPos, "Medial"
	// Symmetric heatmap
	DoWindow/K CMM_Graph2_cent
	NewImage/S=0 CMM_symmMatrix_cent
	JT_NameWin("CMM_Graph2_cent","Centered Symmetric Connectivity Heatmap")
	ModifyImage CMM_symmMatrix_cent ctab= {*,*,CMM_LUT,0}
	ColorScale/C/N=text0/A=RB/X=10.00/Y=5.00/B=(0,0,0)/G=(65535,65535,65535) image=CMM_symmMatrix_cent, heightPct=25, widthPct=3, fsize=10,"amplitude (\\U)"
	ModifyGraph width={Plan,1,top,left}
	CMM_addScaleBar()
	CMM_addLayerLines_cent()
	CMM_addColumnLines()
	CMM_addPostCell_cent()
	CMM_addCircleAroundSoma_cent()
	CMM_addTheNs(CMM_ExpList)
	
	//// MAPS IN DISTORTED COORDINATES
	// Asymmetric heatmap
	DoWindow/K CMM_Graph1_dist
	NewImage/S=0 CMM_asymmMatrix_dist
	JT_NameWin("CMM_Graph1_dist","Distorted Asymmetric Connectivity Heatmap")
	ModifyImage CMM_asymmMatrix_dist ctab= {*,*,CMM_LUT,0}
	ColorScale/C/N=text0/A=RB/X=10.00/Y=5.00/B=(0,0,0)/G=(65535,65535,65535) image=CMM_asymmMatrix_dist, heightPct=25, widthPct=3, fsize=10,"amplitude (\\U)"
	ModifyGraph width={Plan,1,top,left}
	CMM_addScaleBar()
	CMM_addLayerLines()
	CMM_addColumnLines()
	CMM_addPostCell_dist()
	CMM_addCircleAroundSoma_dist()
	CMM_addTheNs(CMM_ExpList)
	// Indicate where medial side is
	SetDrawLayer UserFront
	SetDrawEnv linethick= 2,linefgc= (65535,65535,65535),fillpat= 0,xcoord= prel,ycoord= prel,arrow= 2,arrowfat=0.75
	DrawLine xPos-arrowLen/2,yPos,xPos+arrowLen/2,yPos
	SetDrawEnv textxjust= 1,textyjust= 2,fname= "Arial",fstyle= 3, textrgb= (65535,65535,65535),fsize=10
	yPos += 0.01
	DrawText xPos,yPos, "Medial"
	// Symmetric heatmap
	DoWindow/K CMM_Graph2_dist
	NewImage/S=0 CMM_symmMatrix_dist
	JT_NameWin("CMM_Graph2_dist","Distorted Symmetric Connectivity Heatmap")
	ModifyImage CMM_symmMatrix_dist ctab= {*,*,CMM_LUT,0}
	ColorScale/C/N=text0/A=RB/X=10.00/Y=5.00/B=(0,0,0)/G=(65535,65535,65535) image=CMM_symmMatrix_dist, heightPct=25, widthPct=3, fsize=10,"amplitude (\\U)"
	ModifyGraph width={Plan,1,top,left}
	CMM_addScaleBar()
	CMM_addLayerLines()
	CMM_addColumnLines()
	CMM_addPostCell_dist()
	CMM_addCircleAroundSoma_dist()
	CMM_addTheNs(CMM_ExpList)
	
	//// Create cortical cross-section profile density
	NVAR		xMin = CMM_xMin_dist
	NVAR		xMax = CMM_xMax_dist
	NVAR		yMin = CMM_yMin_dist
	NVAR		yMax = CMM_yMax_dist
	NVAR		CMM_gaussDiam
	NVAR		CMM_fillScale
	Variable	pad = CMM_gaussDiam*CMM_fillScale*1.05		// Add a margin to account for rounding errors
	Make/O/N=(5000) CMM_CrossSectionX,CMM_CrossSectionY
	SetScale/I x,xMin-pad,xMax+pad,"µm",CMM_CrossSectionX
	SetScale/I x,yMin-pad,yMax+pad,"µm",CMM_CrossSectionY
	CMM_CrossSectionX = 0
	CMM_CrossSectionY = 0
	i = 0
	do
		currExp = StringFromList(i,CMM_ExpList)
		WAVE		wx_dist = $(currExp+"_cellX_dist")
		WAVE		wy_dist = $(currExp+"_cellY_dist")
		WAVE		amp = $(currExp+"_UseAmp")
		WAVE		resp = $(currExp+"_Resp")
		WAVE	/T	data = $(currExp+"_data")
		if (stringMatch(data[8],"Right"))		// Medial surface to the right means the data has to be flipped over along the x-axis
			xSign = -1
		else
			xSign = 1
		endif
		// Absolute coordinates
		Duplicate/O wx_dist,wTemp
		wTemp *= xSign
		CMM_AddToCrossSection(wTemp,wy_dist,amp,resp)
		i += 1
	while(i<nExps)
	CMM_plotCrossSectionY()
	CMM_plotCrossSectionX()		// Sloppy dependency: CMM_plotCrossSectionX must execute after CMM_plotCrossSectionY

	//// Radial connectivity and amplitude
	// RPercConn;RConn;RCells;RX;RAmpMean;RAmpSEM;
	// RPPRMean;RPPRSEM;
	currExp = StringFromList(0,CMM_ExpList)
	WAVE		wy = $(currExp+"_RPercConn")
	WAVE		wx = $(currExp+"_RX")
	WAVE		amp = $(currExp+"_RAmpMean")
	WAVE		PPR = $(currExp+"_RPPRMean")
	Duplicate/O wy,radPercConnMean,radPercConnSEM
	Duplicate/O amp,radAmpMean,radAmpSEM
	Duplicate/O PPR,radPPRMean,radPPRSEM
	radPercConnMean = 0
	radPercConnSEM = 0
	radAmpMean = 0
	radAmpSEM = 0
	radPPRMean = 0
	radPPRSEM = 0
	Duplicate/O wx,radX
	Variable	nPPR
	Variable	radialStep = radX[1]-radX[0]
	Variable	nBins = numpnts(radX)
	Variable/G	CMM_nRadConn = 0
	Variable/G	CMM_nRadTested = 0
	nPPR = 0
	j = 0
	do
		Make/O/N=(0) workWave1,workWave2,workWave3
		i = 0
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		wy = $(currExp+"_RPercConn")
			WAVE		amp = $(currExp+"_RAmpMean")
			WAVE		PPR = $(currExp+"_RPPRMean")
			workWave1[numpnts(workWave1)] = {wy[j]}
			workWave2[numpnts(workWave2)] = {amp[j]}
			workWave3[numpnts(workWave3)] = {PPR[j]}
			if (j==0)
				WAVE		wRadConn = $(currExp+"_RConn")
				WAVE		wRadTested = $(currExp+"_RCells")
				WAVE		PPRall = $(currExp+"_PPR")
				CMM_nRadConn += sum(wRadConn)
				CMM_nRadTested += sum(wRadTested)
				WaveStats/Q PPRall
				nPPR += V_npnts
			endif
			i += 1
		while(i<nExps)
		WaveStats/Q workWave1
		radPercConnMean[j] = V_avg
		radPercConnSEM[j] = V_SEM
		WaveStats/Q workWave2
		radAmpMean[j] = V_avg
		radAmpSEM[j] = V_SEM
		WaveStats/Q workWave3
		radPPRMean[j] = V_avg
		radPPRSEM[j] = V_SEM
		j += 1
	while(j<nBins)

	// Plot Radial Connectivity
	DoWindow/K CMM_Graph3
	Display /W=(35,53,572,389) radPercConnMean vs radX as "Radial connectivity"
	DoWindow/C CMM_Graph3
	ModifyGraph mode=5
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	ModifyGraph manTick(left)={0,10,0,0},manMinor(left)={1,0}
	SetAxis/A/N=1/E=1 left
	SetAxis bottom,0,radX[numpnts(radX)-1-1]
	
	AppendToGraph radPercConnMean vs radX
	ModifyGraph mode(radPercConnMean#1)=2
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph offset(radPercConnMean#1)={radialStep/2,0}
	ErrorBars radPercConnMean#1 Y,wave=(radPercConnSEM,radPercConnSEM)

	K0 = 0;K1=radPercConnMean[0];						// Constrain to pass through max value, JSj 3 Feb 2023
	CurveFit/H="110"/Q/M=2/W=0 exp, radPercConnMean/X=radX/D
	ModifyGraph lstyle(fit_radPercConnMean)=2,lsize(fit_radPercConnMean)=2
	ModifyGraph rgb(fit_radPercConnMean)=(65535,0,0)//,65535/2)
	WAVE		W_coef
	Variable/G	CMM_radialTau = 1/W_coef[2]

	Label left "connectivity (%)"
	Label bottom "radius (µm)"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01Radial connectivity\\f00\r"+num2str(CMM_nRadConn)+"/"+num2str(CMM_nRadTested)+" ("+num2str(Round(CMM_nRadConn/CMM_nRadTested*100))+"%) onto "+num2str(nExps)+" cells\r\\s(fit_radPercConnMean) tau = "+num2str(round(CMM_radialTau))+" µm"
	ModifyGraph margin(left)=48,nticks(left)=3
	
	// Plot Radial Amplitude
	DoWindow/K CMM_Graph4
	Display /W=(35,53,572,389) radAmpMean vs radX as "Radial amplitude"
	DoWindow/C CMM_Graph4
	ModifyGraph mode=5
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	SetAxis/A/N=1 left
	SetAxis bottom,0,radX[numpnts(radX)-1-1]
	
	AppendToGraph radAmpMean vs radX
	ModifyGraph mode(radAmpMean#1)=2
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph offset(radAmpMean#1)={radialStep/2,0}
	ErrorBars radAmpMean#1 Y,wave=(radAmpSEM,radAmpSEM)

	Label left "amplitude (mV)\\u#2"
	Label bottom "radius (µm)"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01Radial EPSP amplitude\\f00\r"+num2str(CMM_nRadConn)+"/"+num2str(CMM_nRadTested)+" ("+num2str(Round(CMM_nRadConn/CMM_nRadTested*100))+"%) onto "+num2str(nExps)+" cells"
	ModifyGraph margin(left)=48,nticks(left)=3
	
	// Plot Radial PPR
	DoWindow/K CMM_Graph10
	Display /W=(35,53,572,389) radPPRMean vs radX as "Radial PPR"
	DoWindow/C CMM_Graph10
	ModifyGraph mode=5
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	SetAxis/A/N=1 left
	SetAxis bottom,0,radX[numpnts(radX)-1-1]
	
	AppendToGraph radPPRMean vs radX
	ModifyGraph mode(radPPRMean#1)=2
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph offset(radPPRMean#1)={radialStep/2,0}
	ErrorBars radPPRMean#1 Y,wave=(radPPRSEM,radPPRSEM)

	Label left "PPR"
	Label bottom "radius (µm)"
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01Radial PPR\\f00\r"+num2str(nPPR)+" inputs onto "+num2str(nExps)+" cells"
	ModifyGraph margin(left)=48,nticks(left)=3
	
	//// EPSP histogram
	print "Make EPSP histogram of all inputs"
	// Resp;cellX;cellY;cellZ;UseAmp;PPR;
	String	wList = ""
	i = 0
	do
		currExp = StringFromList(i,CMM_ExpList)
		wList += currExp+"_UseAmp;"
		WAVE 	w = $(currExp+"_UseAmp")
		WaveStats/Q w
		print currExp+" | max: "+num2str(V_max*1e3)+" mV, min: "+num2str(V_min*1e3)+" mV"
		i += 1
	while(i<nExps)
	Concatenate/O/NP wList,allUseAmp
	JT_RemoveNaNs(allUseAmp)
	
	//// Linear EPSP histogram
	// This is CMM_Graph5
//	CMM_LinBinHist()

	//// LogNormal EPSP histogram
	// This is CMM_Graph6
	CMM_logBinHist()

	//// Connectivity across layers
	// LPercConn;LConn;LCells;LLabels;
	currExp = StringFromList(0,CMM_ExpList)
	WAVE		theMean = $(currExp+"_LPercConn")
	WAVE/T		theLabels = $(currExp+"_LLabels")
	Duplicate/O theMean,LPercConnMean,LPercConnSEM
	Duplicate/T/O theLabels,wLayerLabels
	LPercConnMean = 0
	LPercConnSEM = 0
	Variable	nLayers = numpnts(wLayerLabels)
	Variable/G	CMM_nLayConnected = 0
	Variable/G	CMM_nLayTested = 0
	j = 0
	do
		Make/O/N=(0) workWave1
		i = 0
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		currW = $(currExp+"_LPercConn")
			workWave1[numpnts(workWave1)] = {currW[j]}
			if (j==0)
				WAVE		currWConn = $(currExp+"_LConn")
				WAVE		currWTested = $(currExp+"_LCells")
				CMM_nLayConnected += sum(currWConn)
				CMM_nLayTested += sum(currWTested)
			endif
			i += 1
		while(i<nExps)
		WaveStats/Q workWave1
		LPercConnMean[j] = V_avg
		LPercConnSEM[j] = V_SEM
		j += 1
	while(j<nLayers)
	
	DoWindow/K CMM_Graph7
	Display /W=(143,528,538,736) LPercConnMean vs wLayerLabels as "Layer connectivity"
	DoWindow/C CMM_Graph7
	ModifyGraph mode(LPercConnMean)=5
	ModifyGraph rgb(LPercConnMean)=(33536,40448,47872)
	ErrorBars LPercConnMean Y,wave=(LPercConnSEM,LPercConnSEM)
	ModifyGraph hbFill(LPercConnMean)=2
	ModifyGraph useBarStrokeRGB(LPercConnMean)=1
	ModifyGraph manTick(left)={0,10,0,0},manMinor(left)={1,50}
	Label left "connectivity (%)"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Connectivity across layers\\f00\r"+num2str(CMM_nLayConnected)+"/"+num2str(CMM_nLayTested)+" ("+num2str(Round(CMM_nLayConnected/CMM_nLayTested*100))+"%) onto "+num2str(nExps)+" cells"

	//// Connectivity within columnm across layers
	// CLPercConn;CLConn;CLCells;
	currExp = StringFromList(0,CMM_ExpList)
	WAVE		theMean = $(currExp+"_CLPercConn")
	WAVE/T		theLabels = $(currExp+"_LLabels")
	Duplicate/O theMean,CLPercConnMean,CLPercConnSEM
	CLPercConnMean = 0
	CLPercConnSEM = 0
	Variable/G	CMM_nColConnected = 0
	Variable/G	CMM_nColTested = 0
	j = 0
	do
		Make/O/N=(0) workWave1
		i = 0
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		currW = $(currExp+"_CLPercConn")
			workWave1[numpnts(workWave1)] = {currW[j]}
			if (j==0)
				WAVE		currWConn = $(currExp+"_CLConn")
				WAVE		currWTested = $(currExp+"_CLCells")
				CMM_nColConnected += sum(currWConn)
				CMM_nColTested += sum(currWTested)
			endif
			i += 1
		while(i<nExps)
		WaveStats/Q workWave1
		CLPercConnMean[j] = V_avg
		CLPercConnSEM[j] = V_SEM
		j += 1
	while(j<nLayers)
	
	DoWindow/K CMM_Graph8
	Display /W=(143,528,538,736) CLPercConnMean vs wLayerLabels as "Layer connectivity within column"
	DoWindow/C CMM_Graph8
	ModifyGraph mode(CLPercConnMean)=5
	ModifyGraph rgb(CLPercConnMean)=(33536,40448,47872)
	ErrorBars CLPercConnMean Y,wave=(CLPercConnSEM,CLPercConnSEM)
	ModifyGraph hbFill(CLPercConnMean)=2
	ModifyGraph useBarStrokeRGB(CLPercConnMean)=1
	ModifyGraph manTick(left)={0,10,0,0},manMinor(left)={1,50}
	Label left "connectivity (%)"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Connectivity within column\\f00\r"+num2str(CMM_nColConnected)+"/"+num2str(CMM_nColTested)+" ("+num2str(Round(CMM_nColConnected/CMM_nColTested*100))+"%) onto "+num2str(nExps)+" cells"


	//// Amplitude across layers within column
	// CLAmpMean;CLAmpSEM;	-- Amplitudes across layers and within column
	currExp = StringFromList(0,CMM_ExpList)
	WAVE		theMean = $(currExp+"_CLAmpMean")
	Duplicate/O theMean,CLAmpMean,CLAmpSEM
	CLAmpMean = 0
	CLAmpSEM = 0
	j = 0
	do
		Make/O/N=(0) workWave1
		i = 0
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		currW = $(currExp+"_CLAmpMean")
			workWave1[numpnts(workWave1)] = {currW[j]}
			i += 1
		while(i<nExps)
		WaveStats/Q workWave1
		CLAmpMean[j] = V_avg
		CLAmpSEM[j] = V_SEM
		j += 1
	while(j<nLayers)
	
	DoWindow/K CMM_Graph11
	Display /W=(143,528,538,736) CLAmpMean vs wLayerLabels as "Amplitude within column"
	DoWindow/C CMM_Graph11
	ModifyGraph mode(CLAmpMean)=5
	ModifyGraph rgb(CLAmpMean)=(33536,40448,47872)
	ErrorBars CLAmpMean Y,wave=(CLAmpSEM,CLAmpSEM)
	ModifyGraph hbFill(CLAmpMean)=2
	ModifyGraph useBarStrokeRGB(CLAmpMean)=1
	Label left "amplitude (mV)\\u#2"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Amplitude within column (post)\\f00\r"+num2str(CMM_nColConnected)+"/"+num2str(CMM_nColTested)+" ("+num2str(Round(CMM_nColConnected/CMM_nColTested*100))+"%) onto "+num2str(nExps)+" cells"

	//// Pathway strength within column -- connectivity times amplitude
	Duplicate/O CLAmpMean,PathwayStrength
	PathwayStrength = CLAmpMean*CLPercConnMean
	
	DoWindow/K CMM_Graph12
	Display /W=(143,528,538,736) PathwayStrength vs wLayerLabels as "Pathway strength"
	DoWindow/C CMM_Graph12
	ModifyGraph mode(PathwayStrength)=5
	ModifyGraph rgb(PathwayStrength)=(33536,40448,47872)
	ModifyGraph hbFill(PathwayStrength)=2
	ModifyGraph useBarStrokeRGB(PathwayStrength)=1
	Label left "strength (mV%)"
	SetAxis/A/N=2 left,0,*
	ModifyGraph prescaleExp(left)=3
	SetAxis/A/R bottom
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Pathway strength\\f00\r"+num2str(CMM_nColConnected)+"/"+num2str(CMM_nColTested)+" ("+num2str(Round(CMM_nColConnected/CMM_nColTested*100))+"%) onto "+num2str(nExps)+" cells"

	//// PPR across layers, averaged across all postsynaptic cells
	// LPPRMean;LPPRSEM;					-- PPR across layers (not within column)
	currExp = StringFromList(0,CMM_ExpList)
	WAVE		theMean = $(currExp+"_LPPRMean")
	Duplicate/O theMean,PPRmean,PPRSEM
	PPRmean = 0
	PPRSEM = 0
	nPPR = 0
	j = 0
	do
		Make/O/N=(0) workWave1
		i = 0
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		currW = $(currExp+"_LPPRMean")
			workWave1[numpnts(workWave1)] = {currW[j]}
			if (j==0)
				WAVE		currSourcePPR = $(currExp+"_PPR")
				Duplicate/O currSourcePPR,wTemp
				JT_RemoveNaNs(wTemp)
				nPPR += numpnts(wTemp)
			endif
			i += 1
		while(i<nExps)
		WaveStats/Q workWave1
		PPRmean[j] = V_avg
		PPRSEM[j] = V_SEM
		j += 1
	while(j<nLayers)
	
	DoWindow/K CMM_Graph9
	Display /W=(143,528,538,736) PPRmean vs wLayerLabels as "PPR across layers (post)"
	DoWindow/C CMM_Graph9
	ModifyGraph mode(PPRmean)=5
	ModifyGraph rgb(PPRmean)=(33536,40448,47872)
	ErrorBars PPRmean Y,wave=(PPRSEM,PPRSEM)
	ModifyGraph hbFill(PPRmean)=2
	ModifyGraph useBarStrokeRGB(PPRmean)=1
	Label left "PPR"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01PPR across layers (post)\\f00\r"+num2str(nExps)+" cells"

	//// PPR across layers, across individual presynaptic inputs
	currExp = StringFromList(0,CMM_ExpList)
	WAVE		theMean = $(currExp+"_LPPRMean")
	Duplicate/O theMean,PPRmean2,PPRSEM2
	PPRmean2 = 0
	PPRSEM2 = 0
	Make/O/T/N=(numpnts(theMean)) wPPRlayerNs
	wPPRlayerNs = ""
	nPPR = 0

	j = 0				// Counting all layers
	do
		Make/O/N=(0) workWave1
		i = 0			// Counting all experiments
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		PPRW = $(currExp+"_PPR")
			WAVE		layerW = $(currExp+"_layerLoc")
			WAVE		resp = $(currExp+"_Resp")
			k = 1		// Counting all cells in each experiments _EXCEPT_ the postsynaptic cell
			do
				if (j == layerW[k])
					workWave1[numpnts(workWave1)] = {PPRW[k]}
				endif
				k += 1
			while(k<numpnts(PPRW))
			i += 1
		while(i<nExps)
		JT_RemoveNaNs(workWave1)
		nPPR += numpnts(workWave1)
		wPPRlayerNs[j] = " "+num2str(numpnts(workWave1))
		if (numpnts(workWave1)>2)
			WaveStats/Q workWave1
			PPRmean2[j] = V_avg
			PPRSEM2[j] = V_SEM
		else
			if (numpnts(workWave1)>0)
				PPRmean2[j] = Mean(workWave1)
			endif
		endif
		Duplicate/O workWave1,$("allPPRforLayer"+num2str(j+1))
		j += 1
	while(j<nLayers)
	Duplicate/O PPRmean2,PPRmean2b
	PPRmean2b = PPRmean2+PPRSEM2

	DoWindow/K CMM_Graph13
	Display /W=(143,528,538,736) PPRmean2b,PPRmean2 vs wLayerLabels as "PPR across layers (pre)"
	DoWindow/C CMM_Graph13
	ModifyGraph mode(PPRmean2b)=3
	ModifyGraph mode(PPRmean2)=5
	ModifyGraph hbFill(PPRmean2)=2
	ModifyGraph rgb(PPRmean2)=(33536,40448,47872)
	ErrorBars PPRmean2 Y,wave=(PPRSEM2,PPRSEM2)
	ModifyGraph rgb(PPRmean2b)=(0,0,0)
	ModifyGraph toMode(PPRmean2b)=-1
	ModifyGraph textMarker(PPRmean2b)={wPPRlayerNs,"default",1,0,4,0.00,0.00}
	ModifyGraph useBarStrokeRGB(PPRmean2)=1
	Label left "PPR"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	CMM_createSigMatrix("allPPRforLayer",6)
	Variable/G JT_SigLinesFlipY = 1			// Flag: Draw error bars on other side of graph to account for ModifyGraph swapXY = 1 bug
	WAVE	sigMatrix
	JT_SigLinesFlipY = 1
	JT_AllBarsSigStars("",sigMatrix)
	JT_SigLinesFlipY = 0
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01PPR across layers (pre)\\f00\r"+num2str(nPPR)+" inputs to "+num2str(nExps)+" cells"

	//// Amplitude across layers, within column, across individual _presynaptic_ inputs
	// CLAmpMean2;CLAmpSEM2;	-- Amplitudes (pre) across layers and within column
	// CLAmpMean3;CLAmpSEM3;	-- Amplitudes (pre) across layers, disregarding column
	currExp = StringFromList(0,CMM_ExpList)
	WAVE		theMean = $(currExp+"_CLAmpMean")
	Duplicate/O theMean,CLAmpMean2,CLAmpSEM2,CLAmpMean3,CLAmpSEM3
	CLAmpMean2 = 0
	CLAmpSEM2 = 0
	CLAmpMean3 = 0
	CLAmpSEM3 = 0
	Make/O/T/N=(numpnts(theMean)) wAmplayerNs2,wAmplayerNs3
	wAmplayerNs2 = ""
	wAmplayerNs3 = ""
	Variable	nAmp2 = 0
	Variable	nAmp3 = 0
	
	NVAR		CMM_columnWidth				// Column width in µm

	j = 0			// Counting all layers
	do
		Make/O/N=(0) workWave2
		Make/O/N=(0) workWave3
		i = 0		// Counting all experiments
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		AmpW = $(currExp+"_UseAmp")
			WAVE		layerW = $(currExp+"_layerLoc")
			WAVE		resp = $(currExp+"_Resp")
			WAVE		xCoord = $(currExp+"_cellX")
			WAVE		yCoord = $(currExp+"_cellY")
			k = 1		// Counting all cells in each experiments _EXCEPT_ the postsynaptic cell
			do
				if (j == layerW[k])
					if (abs(xCoord[k])<CMM_columnWidth/2)		// Only count points within the column
						workWave2[numpnts(workWave2)] = {AmpW[k]}
					endif
					workWave3[numpnts(workWave3)] = {AmpW[k]}
				endif
				k += 1
			while(k<numpnts(AmpW))
			i += 1
		while(i<nExps)
		JT_RemoveNaNs(workWave2)
		JT_RemoveNaNs(workWave3)
		nAmp2 += numpnts(workWave2)
		nAmp3 += numpnts(workWave3)
		wAmplayerNs2[j] = " "+num2str(numpnts(workWave2))
		wAmplayerNs3[j] = " "+num2str(numpnts(workWave3))
		
		if (numpnts(workWave2)>2)
			WaveStats/Q workWave2
			CLAmpMean2[j] = V_avg
			CLAmpSEM2[j] = V_SEM
		else
			if (numpnts(workWave2)>0)
				CLAmpMean2[j] = Mean(workWave2)
			endif
		endif
		
		Duplicate/O workWave2,$("CLAmp_"+num2str(j+1))

		if (numpnts(workWave3)>2)
			WaveStats/Q workWave3
			CLAmpMean3[j] = V_avg
			CLAmpSEM3[j] = V_SEM
		else
			if (numpnts(workWave3)>0)
				CLAmpMean3[j] = Mean(workWave3)
			endif
		endif
		Duplicate/O workWave2,$("allAmpforLayer"+num2str(j+1))
		Duplicate/O workWave3,$("allAmpforLayerOutside"+num2str(j+1))
		j += 1
	while(j<nLayers)
	Duplicate/O CLAmpMean2,CLAmpMean2b
	CLAmpMean2b = CLAmpMean2+CLAmpSEM2
	Duplicate/O CLAmpMean3,CLAmpMean3b
	CLAmpMean3b = CLAmpMean3+CLAmpSEM3
	
	DoWindow/K CMM_Graph14
	Display /W=(143,528,538,736) CLAmpMean2b,CLAmpMean2 vs wLayerLabels as "Amplitude within column (pre)"
	DoWindow/C CMM_Graph14
	ModifyGraph mode(CLAmpMean2b)=3
	ModifyGraph mode(CLAmpMean2)=5
	ModifyGraph hbFill(CLAmpMean2)=2
	ModifyGraph rgb(CLAmpMean2)=(33536,40448,47872)
	ErrorBars CLAmpMean2 Y,wave=(CLAmpSEM2,CLAmpSEM2)
	ModifyGraph rgb(CLAmpMean2b)=(0,0,0)
	ModifyGraph toMode(CLAmpMean2b)=-1
	ModifyGraph textMarker(CLAmpMean2b)={wAmplayerNs2,"default",1,0,4,0.00,0.00}
	ModifyGraph useBarStrokeRGB(CLAmpMean2)=1
	Label left "Amp"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	CMM_createSigMatrix("allAmpforLayer",6)
	JT_SigLinesFlipY = 1			// Flag: Draw error bars on other side of graph to account for ModifyGraph swapXY = 1 bug
	WAVE	sigMatrix
	JT_SigLinesFlipY = 1
	JT_AllBarsSigStars("",sigMatrix)
	JT_SigLinesFlipY = 0
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Amp within column (pre)\\f00\r"+num2str(nAmp2)+" inputs to "+num2str(nExps)+" cells"

	DoWindow/K CMM_Graph15
	Display /W=(143,528,538,736) CLAmpMean3b,CLAmpMean3 vs wLayerLabels as "Amplitude across layers (pre)"
	DoWindow/C CMM_Graph15
	ModifyGraph mode(CLAmpMean3b)=3
	ModifyGraph mode(CLAmpMean3)=5
	ModifyGraph hbFill(CLAmpMean3)=2
	ModifyGraph rgb(CLAmpMean3)=(33536,40448,47872)
	ErrorBars CLAmpMean3 Y,wave=(CLAmpSEM3,CLAmpSEM3)
	ModifyGraph rgb(CLAmpMean3b)=(0,0,0)
	ModifyGraph toMode(CLAmpMean3b)=-1
	ModifyGraph textMarker(CLAmpMean3b)={wAmplayerNs3,"default",1,0,4,0.00,0.00}
	ModifyGraph useBarStrokeRGB(CLAmpMean3)=1
	Label left "Amp"
	SetAxis/A/N=2 left,0,*
	SetAxis/A/R bottom
	CMM_createSigMatrix("allAmpforLayer",6)
	JT_SigLinesFlipY = 1			// Flag: Draw error bars on other side of graph to account for ModifyGraph swapXY = 1 bug
	WAVE	sigMatrix
	JT_SigLinesFlipY = 1
	JT_AllBarsSigStars("",sigMatrix)
	JT_SigLinesFlipY = 0
	ModifyGraph swapXY=1
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=0.00 "\\f01Amp across layers (pre)\rOutside column too\\f00\r"+num2str(nAmp3)+" inputs to "+num2str(nExps)+" cells"

	//// Angular connectivity histograms
	Variable	nAngularBins = 8
	Make/O/N=(nAngularBins)	histAngularNInputs,histAngularNTested,histAngularConn,histAngularAmpMean,histAngularAmpSEM,wAngles
	SetScale/I x 0,360-360/nAngularBins,"°",histAngularNInputs,histAngularNTested,histAngularConn,histAngularAmpMean,histAngularAmpSEM,wAngles
	histAngularNInputs = 0
	histAngularNTested = 0
	histAngularAmpMean = 0
	histAngularAmpSEM = 0
	wAngles = x
	Variable	AngleStep = wAngles[1]-wAngles[0]
	Variable	currAngle
	NVAR		CMM_localRadius
	Variable	conditional
	ControlInfo/W=CMMPanel analysisMode
	Variable	analysisMode = V_value

	j = 0			// Counting all angular histogram bins
	do
		Make/O/N=(0) $("workWave"+num2str(j+1))
		WAVE		w = $("workWave"+num2str(j+1))
		i = 0		// Counting all experiments
		do
			currExp = StringFromList(i,CMM_ExpList)
			WAVE		AmpW = $(currExp+"_UseAmp")
			WAVE		layerW = $(currExp+"_layerLoc")
			WAVE		resp = $(currExp+"_Resp")
			WAVE		xCoord = $(currExp+"_cellX")
			WAVE		yCoord = $(currExp+"_cellY")
			WAVE		zCoord = $(currExp+"_cellZ")
			k = 1		// Counting all cells in each experiments _EXCEPT_ the postsynaptic cell
			do
				switch(analysisMode)
					case 1:
						conditional = (1)											// Look outside the column, at all data
						break
					case 2:
						conditional = (abs(xCoord[k])<CMM_columnWidth/2)			// Only look within the column
						break
					case 3:
						conditional = (CMM_theDistance(xCoord[0],yCoord[0],zCoord[0],xCoord[k],yCoord[k],zCoord[k])<CMM_localRadius)		// Look within the local sphere
						break
					case 4:
						conditional = (CMM_theDistance(xCoord[0],yCoord[0],0,xCoord[k],yCoord[k],0)<CMM_localRadius)		// Look within the local circle
						break
				endswitch
				if (conditional)
					currAngle = getTheAngle(xCoord[0],yCoord[0],xCoord[k],yCoord[k])
					if (currAngle>360-AngleStep/2)	// Account for circle wrap-around for 0th bin
						currAngle -= 360
					endif
					if ( (currAngle>=wAngles[j]-AngleStep/2) %& (currAngle<wAngles[j]+AngleStep/2) ) 
						if (resp[k])
							histAngularNInputs[j] += 1
							w[numpnts(w)] = {AmpW[k]}
						endif
						histAngularNTested[j] += 1
					endif
				endif
				k += 1
			while(k<numpnts(AmpW))
			i += 1
		while(i<nExps)
		JT_RemoveNaNs(w)
		if (numpnts(w)>2)
			WaveStats/Q w
			histAngularAmpMean[j] = V_avg // median(w)
			histAngularAmpSEM[j] = V_SEM
		else
			if (numpnts(w)>0)
				histAngularAmpMean[j] = Mean(w)
			endif
		endif
		j += 1
	while(j<nAngularBins)
	histAngularConn = histAngularNInputs/histAngularNTested*100
	SetScale d 0,100,"%", histAngularConn
	histAngularConn[numpnts(histAngularConn)] = {histAngularConn[0]}			// Make it wrap in graph (see CMM_ConvertRadialForPlotting)
	histAngularAmpMean *= 1e3
	histAngularAmpSEM *= 1e3
	SetScale d 0,0,"mV", histAngularAmpMean,histAngularAmpSEM
	histAngularAmpMean[numpnts(histAngularAmpMean)] = {histAngularAmpMean[0]}	// Make it wrap in graph
	histAngularAmpSEM[numpnts(histAngularAmpSEM)] = {histAngularAmpSEM[0]}		// Make it wrap in graph
	
	CMM_ConvertRadialForPlotting(histAngularConn,0)
	CMM_ConvertRadialForPlotting(histAngularAmpMean,0)
	CMM_ConvertRadialForPlotting(histAngularAmpSEM,1)

	// Angular connectivity
	WMClosePolarGraph("CMM_Graph16",0)
	WMNewPolarGraph("_default_", "CMM_Graph16")
	DoWindow/T CMM_Graph16,"Radial connectivity"
	String		polarTraceName = WMPolarAppendTrace("CMM_Graph16",histAngularConn, $"", 360)
	Variable	isFillToOrigin,isFillBehind,fillRed,fillGreen,fillBlue
	String		fillYWaveName,fillXWaveName
	WMPolarGetPolarTraceSettings("CMM_Graph16",polarTraceName,isFillToOrigin,isFillBehind,fillRed,fillGreen,fillBlue,fillYWaveName,fillXWaveName)
	//		[make changes to any of isFillToOrigin,isFillBehind,fillRed,fillGreen,fillBlue,fillAlpha,fillYWaveName,fillXWaveName]
	isFillToOrigin= 1
	WMPolarSetPolarTraceSettings("CMM_Graph16",polarTraceName,isFillToOrigin,isFillBehind,fillRed,fillGreen,fillBlue,fillYWaveName,fillXWaveName)
	WMPolarModifyFillToOrigin("CMM_Graph16",polarTraceName)
	Legend/C/N=text0/J/F=0/B=1/A=LT/X=0.00/Y=0.00 "\\f01Connectivity"

	// Angular synaptic weight
	WMClosePolarGraph("CMM_Graph17",0)
	WMNewPolarGraph("_default_", "CMM_Graph17")
	DoWindow/T CMM_Graph17,"Radial amplitude"
	polarTraceName = WMPolarAppendTrace("CMM_Graph17",histAngularAmpMean, $"", 360)
	WMPolarGetPolarTraceSettings("CMM_Graph17",polarTraceName,isFillToOrigin,isFillBehind,fillRed,fillGreen,fillBlue,fillYWaveName,fillXWaveName)
	//		[make changes to any of isFillToOrigin,isFillBehind,fillRed,fillGreen,fillBlue,fillAlpha,fillYWaveName,fillXWaveName]
	isFillToOrigin= 1
	WMPolarSetPolarTraceSettings("CMM_Graph17",polarTraceName,isFillToOrigin,isFillBehind,fillRed,fillGreen,fillBlue,fillYWaveName,fillXWaveName)
	WMPolarModifyFillToOrigin("CMM_Graph17",polarTraceName)
	String radiusErrorBarsX,radiusErrorBarsY,radiusErrorBarsMrkZ	// outputs
	String radiusErrorBarsMode	// output
	Variable radiusErrorBarsPercent	// output
	Variable radiusErrorBarsConstant	// output
	String radiusErrorBarsPlusWavePath	// output
	String radiusErrorBarsMinusWavePath	// output
	String radiusErrorBarsCapWidthStr	// output ("Auto" else degrees)
	WMPolarGetTraceRadiusErrorBars("CMM_Graph17",polarTraceName,radiusErrorBarsX,radiusErrorBarsY,radiusErrorBarsMrkZ,radiusErrorBarsMode,radiusErrorBarsPercent,radiusErrorBarsConstant,radiusErrorBarsPlusWavePath,radiusErrorBarsMinusWavePath,radiusErrorBarsCapWidthStr)	
	radiusErrorBarsMode = "+/- wave"
	radiusErrorBarsPlusWavePath = "root:histAngularAmpSEM"
	WMPolarSetTraceRadiusErrorBars("CMM_Graph17",polarTraceName,radiusErrorBarsX,radiusErrorBarsY,radiusErrorBarsMrkZ,radiusErrorBarsMode,radiusErrorBarsPercent,radiusErrorBarsConstant,radiusErrorBarsPlusWavePath,radiusErrorBarsMinusWavePath,radiusErrorBarsCapWidthStr)
	WMPolarSetTraceErrorBars("CMM_Graph17",polarTraceName,2,2,1,"65535,0,0,65535")
	WMPolarModifyErrorBars("CMM_Graph17",polarTraceName)
	Legend/C/N=text0/J/F=0/B=1/A=LT/X=0.00/Y=0.00 "\\f01Amplitude"

	//// Vertical profile
	NVAR		xMin = CMM_xMin				// Work from -CMM_columnWidth/2 to CMM_columnWidth/2 instead
	NVAR		xMax = CMM_xMax
	NVAR		yMin = CMM_yMin				// Start at zero
	NVAR		yMax = CMM_yMax
	Variable	vNBins = 32
	Variable	hNBins = 16
	
	Make/O/N=(0) CMM_vProfile,CMM_hProfile
	i = 0		// Counting all experiments
	do
		currExp = StringFromList(i,CMM_ExpList)
		WAVE		AmpW = $(currExp+"_UseAmp")
		WAVE		layerW = $(currExp+"_layerLoc")
		WAVE		resp = $(currExp+"_Resp")
		WAVE		xCoord = $(currExp+"_cellX")
		WAVE		yCoord = $(currExp+"_cellY")
		WAVE		zCoord = $(currExp+"_cellZ")
		k = 1		// Counting all cells in each experiments _EXCEPT_ the postsynaptic cell
		do
			if (abs(xCoord[k])<CMM_columnWidth/2)
				if (resp[k])
					CMM_vProfile[numpnts(CMM_vProfile)] = {yCoord[k]}
					CMM_hProfile[numpnts(CMM_vProfile)] = {xCoord[k]}
				endif
			endif
			k += 1
		while(k<numpnts(AmpW))
		i += 1
	while(i<nExps)

	JT_ArrangeGraphs2("CMM_Graph3;CMM_Graph4;CMM_Graph10;CMM_Graph6;CMM_Graph7;CMM_Graph8;CMM_Graph11;CMM_Graph12;CMM_Graph9;CMM_Graph13;CMM_Graph14;CMM_Graph15;CMM_Graph16;CMM_Graph17;",4,6)
	JT_ArrangeGraphs2(";;;;;;;;;;;;CMM_Graph1;CMM_Graph2;",3,6)
	JT_ArrangeGraphs2(";;;;;;;;;;;;CMM_Graph1_cent;CMM_Graph2_cent;",3,6)
	JT_ArrangeGraphs4(";;;;;;;;;;;;CMM_Graph1_cent;CMM_Graph2_cent;",32,32)			// move graphs a bit
	JT_ArrangeGraphs2(";;;;;;;;;;;;CMM_Graph1_dist;CMM_Graph2_dist;",3,6)
	JT_ArrangeGraphs4(";;;;;;;;;;;;CMM_Graph1_dist;CMM_Graph2_dist;",32*2,32*2)		// move graphs a bit
	doUpdate
	JT_CopyWindowWidth("CMM_Graph1_dist","CMM_CrossSectionXGraph")
	AutoPositionWindow/M=1/R=CMM_Graph1_dist CMM_CrossSectionXGraph
	JT_CopyWindowHeight("CMM_Graph1_dist","CMM_CrossSectionYGraph")
	AutoPositionWindow/M=0/R=CMM_Graph1_dist CMM_CrossSectionYGraph

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Measure the distance between two XYZ coordinates

Function CMM_theDistance(x1,y1,z1,x2,y2,z2)
	Variable	x1,y1,z1,x2,y2,z2
	
	Return sqrt( (x1-x2)^2 + (y1-y2)^2 + (z1-z2)^2 )

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Convert the angular histograms to something that makes them look like a rose plot.

Function CMM_ConvertRadialForPlotting(sourceWave,errorBarsMode)
	WAVE		sourceWave
	Variable	errorBarsMode					// Waves containing errorbars values should be treated differently
	
	WAVE		wAngles
	Variable	AngleStep = wAngles[1]-wAngles[0]
	
	Variable	pointsPerBin = 33
	Variable	minVal = 0
	Variable	storeVal
	
	Make/O/N=(0) wTemp
	
	Variable	n = numpnts(sourceWave)-1		// Recall that the last bin was added manually to make the plot wrap, so we ignore that here
	Variable	i,j
	i = 0
	do
		if (errorBarsMode)
			wTemp[numpnts(wTemp)] = {NaN}
		else
			wTemp[numpnts(wTemp)] = {0}
		endif
		j = 0
		do
			StoreVal = sourceWave[i]
			if ( (errorBarsMode) %& (j!=Round(pointsPerBin/2)-1) )
				StoreVal = NaN					// Errorbars should only show up centered on the rose plot bin
			endif
			wTemp[numpnts(wTemp)] = {StoreVal}
			j += 1
		while(j<pointsPerBin)
		i += 1
	while(i<n)
	wTemp[numpnts(wTemp)] = {0}
	SetScale/I x -AngleStep/2,360-AngleStep/2,"°",wTemp
	Duplicate/O wTemp,sourceWave

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Return the angle (in degrees) from the presynaptic input to the postsynaptic cell
//// Angle is defined as for the unit circle, so 90° is straight up, and 0° is to the right
//// However, remember that origin of images is top-left rather than bottom-left, so y-axis is inverted

Function getTheAngle(postX,postY,preX,preY)
	Variable	postX,postY,preX,preY
	
	Variable	theAngle = atan2(-(postY-preY),(postX-preX))/Pi*180+180	// Note nasty switch of X Y to Y X in atan2
	
	if (theAngle>=360)
		theAngle -= 360
	endif
	
	Return		theAngle

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the sig matrix for plotting significance hooks

Function CMM_createSigMatrix(baseName,nCat)
	String		baseName
	Variable	nCat
	
	Make/O/N=(nCat,nCat) sigMatrix
	sigMatrix = 1
	Variable	i,j
	Variable	pVal
	i = 0
	do
		j = i+1
		do
			Duplicate/O $(baseName+num2str(i+1)),w1
			Duplicate/O $(baseName+num2str(j+1)),w2
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
//// Add the n's

Function CMM_addTheNs(expList)
	String		expList
	
	Variable	pad = 0.01

	Variable	n = itemsInList(expList)
	
	Variable	nConn = 0
	Variable	nTested = 0

	String		currExp
	Variable	i,j
	Variable	curr_nConn
	Make/O/N=(0) workWave
	i = 0
	do
		currExp = StringFromList(i,expList)
		WAVE		amp = $(currExp+"_UseAmp")
		WAVE		resp = $(currExp+"_Resp")
		curr_nConn = sum(resp,1,Inf)		// Remember that index 0 corresponds to postsynaptic cell, so ignore this
		nConn += curr_nConn
		nTested += numpnts(resp)-1
		j = 0
		do
			if (resp[j])
				workWave[numpnts(workWave)] = {amp[j]}
			endif
			j += 1
		while(j<numpnts(amp))
		i += 1
	while(i<n)
	
	String	globalStatsStr = ""
	WaveStats/Q/Z workWave
	globalStatsStr += "\\JL"			// Textbox anchor is top right, but text itself is left justified
	globalStatsStr += "n = "+num2str(n)+" cells\r"
	globalStatsStr += "\\f05All inputs:\\f01\r"+num2str(nConn)+"/"+num2str(nTested)+" = "+num2str(Round(nConn/nTested*1000)/10)+"%\r"
	globalStatsStr += num2str(Round(V_avg*1e3*100)/100)+" ± "+num2str(Round(V_SEM*1e3*100)/100)+" mV"

	String	localStatsStr = CMM_doLocalAnalysis()

	SetDrawEnv textxjust= 2,textyjust= 2,fname= "Arial",fstyle= 1, textrgb= (65535,65535,65535),fsize=11,xcoord= prel,ycoord= left
	DrawText 1-pad, 0, globalStatsStr+"\r"+localStatsStr
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add scale bar

Function CMM_addScaleBar()

	Variable	pad = 0.01

	doUpdate
	GetAxis/Q top
	Variable xScale = V_max-V_min
	SetDrawLayer UserFront
	SetDrawEnv linethick= 2,linefgc= (65535,65535,65535),fillpat= 0,xcoord= prel,ycoord= prel
	variable xScBar = pad		// Scale bar position X
	variable yScBar = pad		// Scale bar position Y
	variable	lenScBar = 100	// Scale bar length (µm)
	DrawPoly xScBar,yScBar,1,1,{xScBar, yScBar, xScBar + lenScBar/xScale, yScBar}
	SetDrawEnv textxjust= 1,textyjust= 2,fname= "Arial",fstyle= 1, textrgb= (65535,65535,65535),fsize=9
	DrawText xScBar + lenScBar/xScale/2, yScBar, num2str(lenScBar)+" µm"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add circle around soma to show what local means, ABSOLUTE COORDINATES

Function CMM_addCircleAroundSoma()

	NVAR		CMM_localRadius
	WAVE		CMM_postY_mean
	
	SetDrawLayer UserFront
	// White continuous circle
	SetDrawEnv xcoord= top,ycoord= left,linefgc= (65535,65535,65535),linethick= 1,dash= 0,fillpat= 0
	DrawOval 0-CMM_localRadius,CMM_postY_mean[0]+CMM_localRadius,0+CMM_localRadius,CMM_postY_mean[0]-CMM_localRadius
	// Black dashed circle
	SetDrawEnv xcoord= top,ycoord= left,linefgc= (0,0,0),linethick= 1,dash= 3,fillpat= 0
	DrawOval 0-CMM_localRadius,CMM_postY_mean[0]+CMM_localRadius,0+CMM_localRadius,CMM_postY_mean[0]-CMM_localRadius

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add circle around soma to show what local means, FOR SOMA-CENTERED PLOT

Function CMM_addCircleAroundSoma_cent()

	NVAR		CMM_localRadius
	WAVE		CMM_postY_mean_cent
	
	SetDrawLayer UserFront
	// White continuous circle
	SetDrawEnv xcoord= top,ycoord= left,linefgc= (65535,65535,65535),linethick= 1,dash= 0,fillpat= 0
	DrawOval 0-CMM_localRadius,CMM_postY_mean_cent[0]+CMM_localRadius,0+CMM_localRadius,CMM_postY_mean_cent[0]-CMM_localRadius
	// Black dashed circle
	SetDrawEnv xcoord= top,ycoord= left,linefgc= (0,0,0),linethick= 1,dash= 3,fillpat= 0
	DrawOval 0-CMM_localRadius,CMM_postY_mean_cent[0]+CMM_localRadius,0+CMM_localRadius,CMM_postY_mean_cent[0]-CMM_localRadius

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add circle around soma to show what local means, DISTORTED COORDINATES

Function CMM_addCircleAroundSoma_dist()

	NVAR		CMM_localRadius
	WAVE		CMM_postY_mean_dist
	
	SetDrawLayer UserFront
	// White continuous circle
	SetDrawEnv xcoord= top,ycoord= left,linefgc= (65535,65535,65535),linethick= 1,dash= 0,fillpat= 0
	DrawOval 0-CMM_localRadius,CMM_postY_mean_dist[0]+CMM_localRadius,0+CMM_localRadius,CMM_postY_mean_dist[0]-CMM_localRadius
	// Black dashed circle
	SetDrawEnv xcoord= top,ycoord= left,linefgc= (0,0,0),linethick= 1,dash= 3,fillpat= 0
	DrawOval 0-CMM_localRadius,CMM_postY_mean_dist[0]+CMM_localRadius,0+CMM_localRadius,CMM_postY_mean_dist[0]-CMM_localRadius

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Find the average layer boundaries

Function CMM_addColumnLines()

	NVAR		CMM_columnWidth
	
	Variable	fontSize = 10

	SetDrawEnv xcoord= top,ycoord= prel,fname= "Arial",fstyle= 3,fsize= fontSize,textrgb= (65535,65535,65535)
	SetDrawEnv textxjust= 1,textyjust= 2
	DrawText 0,0,"Column"
	SetDrawLayer UserFront
	SetDrawEnv xcoord= top,ycoord= prel,linefgc= (65535,65535,65535),linethick= 1,dash= 1
	DrawLine -CMM_columnWidth/2,0,-CMM_columnWidth/2,1
	SetDrawEnv xcoord= top,ycoord= prel,linefgc= (65535,65535,65535),linethick= 1,dash= 1
	DrawLine CMM_columnWidth/2,0,CMM_columnWidth/2,1

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add location of postsynaptic cell

Function CMM_addPostCell()

	WAVE		CMM_postY_scatterY,CMM_postY_scatterX		// scatterY and corresponding x-axis wave
	WAVE		CMM_postY_mean,CMM_postY_SEM				// mean ± SEM

	// Postsyn cells
	AppendToGraph/T CMM_postY_scatterY vs CMM_postY_scatterX
	ModifyGraph rgb(CMM_postY_scatterY)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_scatterY)=3
	ModifyGraph mode(CMM_postY_scatterY)=3,marker(CMM_postY_scatterY)=60
	ModifyGraph mrkThick(CMM_postY_scatterY)=0.5,useMrkStrokeRGB(CMM_postY_scatterY)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_scatterY)=(0,26611/2,65535/2)

	// Postsyn cell
	AppendToGraph/T CMM_postY_mean
	ModifyGraph rgb(CMM_postY_mean)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_mean)=8							
	ModifyGraph mode(CMM_postY_mean)=3,marker(CMM_postY_mean)=60
	ModifyGraph mrkThick(CMM_postY_mean)=1,useMrkStrokeRGB(CMM_postY_mean)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_mean)=(0,26611,65535)
	ErrorBars/RGB=(0,26611,65535) CMM_postY_mean Y,wave=(CMM_postY_SEM,CMM_postY_SEM)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add location of postsynaptic cell, FOR SOMA-CENTERED GRAPH

Function CMM_addPostCell_cent()

	WAVE		CMM_postY_mean_cent				// mean ± SEM

	// Postsyn cell
	AppendToGraph/T CMM_postY_mean_cent
	ModifyGraph rgb(CMM_postY_mean_cent)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_mean_cent)=8							
	ModifyGraph mode(CMM_postY_mean_cent)=3,marker(CMM_postY_mean_cent)=60
	ModifyGraph mrkThick(CMM_postY_mean_cent)=1,useMrkStrokeRGB(CMM_postY_mean_cent)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_mean_cent)=(0,26611,65535)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add location of postsynaptic cell, DISTORTED COORDINATES

Function CMM_addPostCell_dist()

	WAVE		CMM_postY_scatterY_dist,CMM_postY_scatterX_dist		// scatterY and corresponding x-axis wave
	WAVE		CMM_postY_mean_dist,CMM_postY_SEM_dist				// mean ± SEM

	// Postsyn cells
	AppendToGraph/T CMM_postY_scatterY_dist vs CMM_postY_scatterX_dist
	ModifyGraph rgb(CMM_postY_scatterY_dist)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_scatterY_dist)=3
	ModifyGraph mode(CMM_postY_scatterY_dist)=3,marker(CMM_postY_scatterY_dist)=60
	ModifyGraph mrkThick(CMM_postY_scatterY_dist)=0.5,useMrkStrokeRGB(CMM_postY_scatterY_dist)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_scatterY_dist)=(0,26611/2,65535/2)

	// Postsyn cell
	AppendToGraph/T CMM_postY_mean_dist
	ModifyGraph rgb(CMM_postY_mean_dist)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_mean_dist)=8							
	ModifyGraph mode(CMM_postY_mean_dist)=3,marker(CMM_postY_mean_dist)=60
	ModifyGraph mrkThick(CMM_postY_mean_dist)=1,useMrkStrokeRGB(CMM_postY_mean_dist)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_mean_dist)=(0,26611,65535)
	ErrorBars/RGB=(0,26611,65535) CMM_postY_mean_dist Y,wave=(CMM_postY_SEM_dist,CMM_postY_SEM_dist)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Draw the average layer boundaries

Function CMM_addLayerLines()

	WAVE		wLayerOffs
	WAVE/T		wLayerSourceLabels
	
	Variable	fontSize = 10
	
	Variable	n = numpnts(wLayerOffs)
	Variable	i
	i = 0
	do
		SetDrawLayer UserFront
		SetDrawEnv ycoord= left,linefgc= (65535,65535,65535),dash= 11
		DrawLine 0,wLayerOffs[i],1,wLayerOffs[i]
		SetDrawEnv xcoord= prel,ycoord= left,textyjust= 2,fname= "Arial",fstyle= 3,fsize=fontSize, textrgb= (65535,65535,65535)
		DrawText 0,wLayerOffs[i],wLayerSourceLabels[i+1]
		if (i==0)
			SetDrawEnv xcoord= prel,ycoord= left,textyjust= 0,fname= "Arial",fstyle= 3,fsize=fontSize, textrgb= (65535,65535,65535)
			DrawText 0,wLayerOffs[i],wLayerSourceLabels[0]
		endif
		i += 1
	while(i<n)
		
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Draw the average layer boundaries, CELL-CENTERED COORDINATES

Function CMM_addLayerLines_cent()

	WAVE		wLayerOffs_cent
	WAVE/T		wLayerSourceLabels
	
	Variable	fontSize = 10
	
	Variable	n = numpnts(wLayerOffs_cent)
	Variable	i
	i = 0
	do
		SetDrawLayer UserFront
		SetDrawEnv ycoord= left,linefgc= (65535,65535,65535),dash= 11
		DrawLine 0,wLayerOffs_cent[i],1,wLayerOffs_cent[i]
		SetDrawEnv xcoord= prel,ycoord= left,textyjust= 2,fname= "Arial",fstyle= 3,fsize=fontSize, textrgb= (65535,65535,65535)
		DrawText 0,wLayerOffs_cent[i],wLayerSourceLabels[i+1]
		if (i==0)
			SetDrawEnv xcoord= prel,ycoord= left,textyjust= 0,fname= "Arial",fstyle= 3,fsize=fontSize, textrgb= (65535,65535,65535)
			DrawText 0,wLayerOffs_cent[i],wLayerSourceLabels[0]
		endif
		i += 1
	while(i<n)
		
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Find the average layer boundaries

Function CMM_analyzeLayers(theExpList)
	String		theExpList
	
	print "Averaging the layers"

	String		currExp
	Variable	currOffs
	WAVE/T		wLayerSourceLabels
	
	Make/O/N=(5)	wLayerOffs
	wLayerOffs = NaN
	
	Variable	nExps = itemsInList(theExpList)
	Variable	nLines = numpnts(wLayerSourceLabels)		// WARNING! Assuming that all layers are indicated!
	Variable	i,j
	j = 0
	do
		Make/O/N=0 workWave1
		i = 0
		do
			currExp = StringFromList(i,theExpList)
			WAVE		wx = $(currExp+"_LLX")
			WAVE		wy = $(currExp+"_LLY")
			if (numpnts(wx)>3*j)
				currOffs = CMM_getLineOffset(wx[j*3],wy[j*3],wx[j*3+1],wy[j*3+1])
				workWave1[numpnts(workWave1)] = {currOffs}
			endif
			i += 1
		while(i<nExps)
		if (numpnts(workWave1)>0)
			WaveStats/Q workWave1
			wLayerOffs[j] = V_avg
			print "\t\tBoundary below layer "+wLayerSourceLabels[j]+": "+num2str(Round(V_avg))+" ± "+num2str(Round(V_SEM))+" µm, n = "+num2str(V_npnts)
		endif
		j += 1
	while (j<nLines-1)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create distorted coordinates that account for the different layer thickness of different cells

Function CMM_createDistortedCoordinates(theExpList)
	String		theExpList

	print "Create distorted coordinates"

	WAVE		wLayerOffs

	// LLX;LLY;		-- Layer boundaries
	// LayerLoc		-- layer location (0 - L1; 1 - L2/3; 2 - L4; 3 - L5; 4 - L6; 5 - WM)
	// ColumnLoc	-- is in column? (boolean)

	String		currExp
	Variable	x1,y1,x2,y2		// Layer line coordinates
	Variable	currLayer
	Variable	dAbove,dBelow,dTotal
	Variable	meanLayerThickness
	Variable	curr_nLayers
	
	Variable	n = itemsInList(theExpList)
	Variable	nPoints
	Variable	i,j
	i = 0
	do
		currExp = StringFromList(i,theExpList)
		WAVE		wx = $(currExp+"_cellX")
		WAVE		wy = $(currExp+"_cellY")
		WAVE		LayerLoc = $(currExp+"_LayerLoc")
		WAVE		LLX = $(currExp+"_LLX")
		WAVE		LLy = $(currExp+"_LLY")
		curr_nLayers = Floor(numpnts(LLX)/3)
		nPoints = numpnts(wx)
		Duplicate/O $(currExp+"_cellX"),$(currExp+"_cellX_dist")
		Duplicate/O $(currExp+"_cellY"),$(currExp+"_cellY_dist")
		WAVE		wx_dist = $(currExp+"_cellX_dist")
		WAVE		wy_dist = $(currExp+"_cellY_dist")
		j = 0
		do
			currLayer = LayerLoc[j]	// This is the layer (number from zero and up) that the current cell (pre or post) lives in
			if (currLayer==0)		// Data points in L1 are not distorted, just offset relative to average layer line below
				print "WARNING! Data point in layer 1 cannot be distorted.\t"+currExp+" data point",j
				x1 = LLX[(currLayer-0)*3]
				x2 = LLX[(currLayer-0)*3+1]
				y1 = LLY[(currLayer-0)*3]
				y2 = LLY[(currLayer-0)*3+1]
				dBelow = CMM_VerticalDistToLine(wx[j],wy[j],x1,y1,x2,y2)		// Vertical distance from x,y to layer line below
				wy_dist[j] = wLayerOffs[currLayer] - dBelow
			endif
			if (currLayer>=curr_nLayers)		// Data points in WM are not distorted, just offset relative to average layer line above
				print "WARNING! Data point in white matter cannot be distorted.\t"+currExp+" data point",j
				x1 = LLX[(currLayer-1)*3]
				x2 = LLX[(currLayer-1)*3+1]
				y1 = LLY[(currLayer-1)*3]
				y2 = LLY[(currLayer-1)*3+1]
				dAbove = CMM_VerticalDistToLine(wx[j],wy[j],x1,y1,x2,y2)		// Vertical distance from x,y to layer line above
				wy_dist[j] = dAbove + wLayerOffs[currLayer-1]
			endif
			if ( (currLayer>0) %& (currLayer<curr_nLayers) )		// Place data point at same fractional distance between layers
				x1 = LLX[(currLayer-1)*3]
				x2 = LLX[(currLayer-1)*3+1]
				y1 = LLY[(currLayer-1)*3]
				y2 = LLY[(currLayer-1)*3+1]
				dAbove = CMM_VerticalDistToLine(wx[j],wy[j],x1,y1,x2,y2)		// Vertical distance from x,y to layer line above
				x1 = LLX[(currLayer-0)*3]
				x2 = LLX[(currLayer-0)*3+1]
				y1 = LLY[(currLayer-0)*3]
				y2 = LLY[(currLayer-0)*3+1]
				dBelow = CMM_VerticalDistToLine(wx[j],wy[j],x1,y1,x2,y2)		// Vertical distance from x,y to layer line below
				dTotal = dAbove + dBelow
				meanLayerThickness = abs(wLayerOffs[currLayer]-wLayerOffs[currLayer-1])
				wy_dist[j] = dAbove/dTotal * meanLayerThickness + wLayerOffs[currLayer-1] // !@#$%
			endif
			j += 1
		while(j<nPoints)
		i += 1
	while(i<n)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Overwrite useAmp values with selected values
	
Function CMM_OverwriteUseAmp(theExpList)
	String		theExpList

	String		currExp
	if (CMM_SavedUseAmpExists(theExpList))
	
		String	sourceSuffix = ""
	
		ControlInfo/W=CMMPanel whichResponseMode
		Variable	whichResponseMode = V_value		// whichResponseMode: Default;EPSP1;EPSP2;EPSP3;Max Depol;
		
		switch(whichResponseMode)
			case 1:			// Default
				sourceSuffix = "_UseAmp_Saved"
				break
			case 2:			// EPSP1
				sourceSuffix = "_Amp1"
				break
			case 3:			// EPSP2
				sourceSuffix = "_Amp2"
				break
			case 4:			// EPSP3
				sourceSuffix = "_Amp3"
				break
			case 5:			// Max Depol
				sourceSuffix = "_MaxDepol"
				break
		endswitch
	
		print "useAmp = "+sourceSuffix
	
		Variable	n = itemsInList(theExpList)
		Variable	i = 0
		do
			currExp = StringFromList(i,theExpList)
			Duplicate/O $(currExp+sourceSuffix),$(currExp+"_UseAmp")
			i += 1
		while(i<n)

	else
	
		Abort "Unfortunately,  the \"_UseAmp_Saved\" waves do not seem to exist.  Try clicking \"Re-init\" and then \"Load folder\"."
	
	endif

End
	
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Paranoia: Do saved useAmp values exist for all experiments?
	
Function CMM_SavedUseAmpExists(theExpList)
	String		theExpList

	String		currExp
	Variable	SavedUseAmpExists = 1
	
	Variable	n = itemsInList(theExpList)
	Variable	i = 0
	do
		currExp = StringFromList(i,theExpList)
		if (Exists(currExp+"_UseAmp_Saved")==0)
			SavedUseAmpExists = 0
			i = Inf
		endif
		i += 1
	while(i<n)
	
	Return SavedUseAmpExists
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Safely store away useAmp values, so that they can be restored later
	
Function CMM_storeAwayUseAmp(theExpList)
	String		theExpList

	print "Storing away useAmp"
	
	String		currExp
	
	Variable	n = itemsInList(theExpList)
	Variable	i = 0
	do
		currExp = StringFromList(i,theExpList)
		Duplicate/O $(currExp+"_UseAmp"),$(currExp+"_UseAmp_Saved")
		i += 1
	while(i<n)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create cell-centered coordinates
//// This is the default for X, so only need to do it for Y, because
//// ..._cellX[0] is always zero, ..._cellY[0] is the distance from boundary between L1 and L2/3
	
Function CMM_createCellCenteredCoords(theExpList)
	String		theExpList

	print "Create cell-centered coordinates"

	String		currExp
	Variable	currCoord
	
	// These waves keep track of _all_ cell-centered coordinates, so that one can plot a cell-centered map of all data points
	Make/O/N=(0)	allCent_cellX,allCent_cellY,allCent_Resp,allCent_UseAmp
	
	Variable	xSign
	
	Variable	n = itemsInList(theExpList)
	Variable	i = 0
	do
		currExp = StringFromList(i,theExpList)
		// Y
		WAVE		wSource = $(currExp+"_cellY")
		currCoord = wSource[0]
		Duplicate/O $(currExp+"_cellY"),$(currExp+"_cellY_cent")
		WAVE		wY = $(currExp+"_cellY_cent")
		wY -= currCoord
		// X -- Not necessary, but do it anyway to prevent future dependencies in the code
		WAVE		wSource = $(currExp+"_cellX")
		currCoord = wSource[0]							// CAREFUL! wSource[0] should be zero anyway, but you never know what future code might bring!!!
		Duplicate/O $(currExp+"_cellX"),$(currExp+"_cellX_cent")
		WAVE		wX = $(currExp+"_cellX_cent")
		wX -= currCoord
		// Store away as _all_ cell-centered coordinates
		WAVE		Resp = $(currExp+"_Resp")
		WAVE		UseAmp = $(currExp+"_UseAmp")
		WAVE/T	Data = $(currExp+"_Data")
		if (stringMatch(data[8],"Right"))		// Medial surface to the right means the data has to be flipped over along the x-axis
			xSign = -1
		else
			xSign = 1
		endif
		Duplicate/O wX,wTempX					// When data is stored away for the overall map, plot as if medial is always to the left
		wTempX *= xSign
		Concatenate/O/NP {allCent_cellX,wTempX},wTempTarget
		Duplicate/O wTempTarget,allCent_cellX
		Concatenate/O/NP {allCent_cellY,wY},wTempTarget
		Duplicate/O wTempTarget,allCent_cellY
		Duplicate/O Resp,wTempResp				// Make sure postsynaptic cell amplitude is set to NaN for compiled plot
		wTempResp[0] = NaN
		Concatenate/O/NP {allCent_Resp,wTempResp},wTempTarget
		Duplicate/O wTempTarget,allCent_Resp
		Concatenate/O/NP {allCent_UseAmp,UseAmp},wTempTarget
		Duplicate/O wTempTarget,allCent_UseAmp
		// Caveats:
		// - coordinate zero contains the postsynaptic cell
		// - unclear if coordinates should be mirrored
		i += 1
	while(i<n)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create radial coordinates
	
Function CMM_createRadialCoords(theExpList)
	String		theExpList

	print "Create cell-centered coordinates"

	Variable	nPoints
	
	String		currExp
	Variable	currCoord
	
	Make/O/N=(0) CMM_allRespOnlyPolarR,CMM_allRespOnlyPolarPhi,CMM_allRespOnlyPolarAmp
	
	Variable	n = itemsInList(theExpList)
	Variable	i,j
	i = 0
	do
		currExp = StringFromList(i,theExpList)
		WAVE		wX = $(currExp+"_cellX_cent")
		WAVE		wY = $(currExp+"_cellY_cent")
		WAVE		Resp = $(currExp+"_Resp")
		WAVE		Amp = $(currExp+"_UseAmp")
		Make/O/C/N=(numpnts(wX)) PolarCoords
		Make/O/N=(numpnts(wX)) $(currExp+"_polarR"),$(currExp+"_polarPhi")
		WAVE		Polar_r = $(currExp+"_polarR")
		WAVE		Polar_Phi = $(currExp+"_polarPhi")
		PolarCoords = r2polar(cmplx(wX,wY))
		Polar_r = real(PolarCoords)
		Polar_Phi=Imag(PolarCoords)
		j = 1
		do
			if (Resp[j])
				CMM_allRespOnlyPolarR[numpnts(CMM_allRespOnlyPolarR)] = {Polar_r[j]}
				CMM_allRespOnlyPolarPhi[numpnts(CMM_allRespOnlyPolarPhi)] = {Polar_Phi[j]}
				CMM_allRespOnlyPolarAmp[numpnts(CMM_allRespOnlyPolarAmp)] = {amp[j]}
			endif
			j += 1
		while(j<numpnts(wX))
		i += 1
	while(i<n)
	
End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Find the mean location (and scatter) of the postsynaptic cells

Function CMM_findPostCellLoc(theExpList)
	String		theExpList

	print "Finding average postsynaptic cell location"

	String		currExp
	
	Make/O/N=(1)	CMM_postY_mean,CMM_postY_SEM				// Location of postsynaptic cell (µm). Note that x is zero by definition.
	Make/O/N=(1)	CMM_postY_mean_cent							// For cell-centered, there is no SEM
	Make/O/N=(1)	CMM_postY_mean_dist,CMM_postY_SEM_dist		// Location of postsynaptic cell (µm). Note that x is zero by definition.
	Variable	n = itemsInList(theExpList)
	Variable	i
	// Absolute coordinates
	i = 0
	Make/O/N=(0)	workWave1
	do
		currExp = StringFromList(i,theExpList)
		WAVE		wy = $(currExp+"_cellY")
		workWave1[numpnts(workWave1)] = {wy[0]}
		i += 1
	while(i<n)
	WaveStats/Q workWave1
	Duplicate/O workWave1,CMM_postY_scatterY,CMM_postY_scatterX
	CMM_postY_scatterX = 0
	print "\t\tAverage y location: "+num2str(V_avg)+" ± "+num2str(V_SEM)+" µm"
	CMM_postY_mean[0] = V_avg
	CMM_postY_SEM[0] = V_SEM
	
	// Cell-centered coordinates
	CMM_postY_mean_cent = 0			// For centered plots, the cell is obviously in the middle
	
	// Distorted coordinates
	i = 0
	Make/O/N=(0)	workWave1
	do
		currExp = StringFromList(i,theExpList)
		WAVE		wy = $(currExp+"_cellY_dist")
		workWave1[numpnts(workWave1)] = {wy[0]}
		i += 1
	while(i<n)
	WaveStats/Q workWave1
	Duplicate/O workWave1,CMM_postY_scatterY_dist,CMM_postY_scatterX_dist
	CMM_postY_scatterX_dist = 0
	print "\t\tAverage y location, distorted coordinates: "+num2str(V_avg)+" ± "+num2str(V_SEM)+" µm"
	CMM_postY_mean_dist[0] = V_avg
	CMM_postY_SEM_dist[0] = V_SEM
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Find min and max coordinates across an arbitrary list of experiments

Function CMM_findMinAndMaxCoordinates(theExpList)
	String		theExpList

	print "Searching for min and max coordinates"
	Variable/G	CMM_xMin = Inf
	Variable/G	CMM_xMax = -Inf
	Variable/G	CMM_yMin = Inf
	Variable/G	CMM_yMax = -Inf
	Variable/G	CMM_xAbsMax = 0
	Variable/G	CMM_yAbsMax = 0

	Variable/G	CMM_xMin_cent = Inf
	Variable/G	CMM_xMax_cent = -Inf
	Variable/G	CMM_yMin_cent = Inf
	Variable/G	CMM_yMax_cent = -Inf
	Variable/G	CMM_xAbsMax_cent = 0
	Variable/G	CMM_yAbsMax_cent = 0

	Variable/G	CMM_xMin_dist = Inf
	Variable/G	CMM_xMax_dist = -Inf
	Variable/G	CMM_yMin_dist = Inf
	Variable/G	CMM_yMax_dist = -Inf
	Variable/G	CMM_xAbsMax_dist = 0
	Variable/G	CMM_yAbsMax_dist = 0

	String		currExp
	
	Variable	xSign = 1
	
	Variable	n = itemsInList(theExpList)
	Variable	i = 0
	do
		currExp = StringFromList(i,theExpList)
		WAVE	/T	data = $(currExp+"_data")
		
		// Absolute coordinates
		WAVE		wx = $(currExp+"_cellX")
		WAVE		wy = $(currExp+"_cellY")
		if (stringMatch(data[8],"Right"))		// Medial surface to the right means the data has to be flipped over along the x-axis
			xSign = -1
		else
			xSign = 1
		endif
		Duplicate/O wx,wTemp
		wTemp *= xSign
		WaveStats/Q wTemp
		If (V_min<CMM_xMin)
			CMM_xMin = Floor(V_Min)
		endif
		If (V_max>CMM_xMax)
			CMM_xMax = Ceil(V_max)
		endif
		WaveStats/Q wy
		If (V_min<CMM_yMin)
			CMM_yMin = Floor(V_Min)
		endif
		If (V_max>CMM_yMax)
			CMM_yMax = Ceil(V_max)
		endif
		
		// Cell-centered coordinates
		WAVE		wx = $(currExp+"_cellX_cent")
		WAVE		wy = $(currExp+"_cellY_cent")
		if (stringMatch(data[8],"Right"))		// Medial surface to the right means the data has to be flipped over along the x-axis
			xSign = -1
		else
			xSign = 1
		endif
		Duplicate/O wx,wTemp
		wTemp *= xSign
		WaveStats/Q wTemp
		If (V_min<CMM_xMin_cent)
			CMM_xMin_cent = Floor(V_Min)
		endif
		If (V_max>CMM_xMax_cent)
			CMM_xMax_cent = Ceil(V_max)
		endif
		WaveStats/Q wy
		If (V_min<CMM_yMin_cent)
			CMM_yMin_cent = Floor(V_Min)
		endif
		If (V_max>CMM_yMax_cent)
			CMM_yMax_cent = Ceil(V_max)
		endif
		
		// Distorted coordinates
		WAVE		wx = $(currExp+"_cellX_dist")
		WAVE		wy = $(currExp+"_cellY_dist")
		if (stringMatch(data[8],"Right"))		// Medial surface to the right means the data has to be flipped over along the x-axis
			xSign = -1
		else
			xSign = 1
		endif
		Duplicate/O wx,wTemp
		wTemp *= xSign
		WaveStats/Q wTemp
		If (V_min<CMM_xMin_dist)
			CMM_xMin_dist = Floor(V_Min)
		endif
		If (V_max>CMM_xMax_dist)
			CMM_xMax_dist = Ceil(V_max)
		endif
		WaveStats/Q wy
		If (V_min<CMM_yMin_dist)
			CMM_yMin_dist = Floor(V_Min)
		endif
		If (V_max>CMM_yMax_dist)
			CMM_yMax_dist = Ceil(V_max)
		endif
		
		i += 1
	while(i<n)
	
	// Absolute coordinates
	if (abs(CMM_xMin) > abs(CMM_xMax))
		CMM_xAbsMax = abs(CMM_xMin)
	else
		CMM_xAbsMax = abs(CMM_xMax)
	endif
	if (abs(CMM_yMin) > abs(CMM_yMax))
		CMM_yAbsMax = abs(CMM_yMin)
	else
		CMM_yAbsMax = abs(CMM_yMax)
	endif
	print "\tABSOLUTE COORDINATES"
	print "\t\tGlobal xMin:",CMM_xMin,"µm"
	print "\t\tGlobal xMax:",CMM_xMax,"µm"
	print "\t\tGlobal yMin:",CMM_yMin,"µm"
	print "\t\tGlobal yMax:",CMM_yMax,"µm"
	print "\t\tGlobal absolute xMax:",CMM_xAbsMax,"µm"
	print "\t\tGlobal absolute yMax:",CMM_yAbsMax,"µm"

	// Cell-centered coordinates
	if (abs(CMM_xMin_cent) > abs(CMM_xMax_cent))
		CMM_xAbsMax_cent = abs(CMM_xMin_cent)
	else
		CMM_xAbsMax_cent = abs(CMM_xMax_cent)
	endif
	if (abs(CMM_yMin_cent) > abs(CMM_yMax_cent))
		CMM_yAbsMax_cent = abs(CMM_yMin_cent)
	else
		CMM_yAbsMax_cent = abs(CMM_yMax_cent)
	endif
	print "\tCELL-CENTERED COORDINATES"
	print "\t\tGlobal xMin:",CMM_xMin_cent,"µm"
	print "\t\tGlobal xMax:",CMM_xMax_cent,"µm"
	print "\t\tGlobal yMin:",CMM_yMin_cent,"µm"
	print "\t\tGlobal yMax:",CMM_yMax_cent,"µm"
	print "\t\tGlobal absolute xMax:",CMM_xAbsMax_cent,"µm"
	print "\t\tGlobal absolute yMax:",CMM_yAbsMax_cent,"µm"

	// Distorted coordinates
	if (abs(CMM_xMin_dist) > abs(CMM_xMax_dist))
		CMM_xAbsMax_dist = abs(CMM_xMin_dist)
	else
		CMM_xAbsMax_dist = abs(CMM_xMax_dist)
	endif
	if (abs(CMM_yMin_dist) > abs(CMM_yMax_dist))
		CMM_yAbsMax_dist = abs(CMM_yMin_dist)
	else
		CMM_yAbsMax_dist = abs(CMM_yMax_dist)
	endif
	print "\tDISTORTED COORDINATES"
	print "\t\tGlobal xMin:",CMM_xMin_dist,"µm"
	print "\t\tGlobal xMax:",CMM_xMax_dist,"µm"
	print "\t\tGlobal yMin:",CMM_yMin_dist,"µm"
	print "\t\tGlobal yMax:",CMM_yMax_dist,"µm"
	print "\t\tGlobal absolute xMax:",CMM_xAbsMax_dist,"µm"
	print "\t\tGlobal absolute yMax:",CMM_yAbsMax_dist,"µm"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the heatmaps

Function CMM_CreateMatrices()

	Variable/G	CMM_gaussDiam = 20
	Variable/G	CMM_fillScale = 3
	Variable	pad = CMM_gaussDiam*CMM_fillScale*1.05		// Add a margin to account for rounding errors
	Variable	StepSize = 2
	
	//// ABSOLUTE COORDINATES
	NVAR		xMin = CMM_xMin
	NVAR		xMax = CMM_xMax
	NVAR		yMin = CMM_yMin
	NVAR		yMax = CMM_yMax
	NVAR		xAbsMax = CMM_xAbsMax
	NVAR		yAbsMax = CMM_yAbsMax
	// Asymmetric matrix
	Variable	xN = floor( (xMax+pad-xMin+pad)/StepSize+1 )
	Variable	yN = floor( (yMax+pad-yMin+pad)/StepSize+1 )
	Make/O/N=(xN,yN) CMM_asymmMatrix
	CMM_asymmMatrix = 0
	SetScale/P x,xMin-pad,StepSize,CMM_asymmMatrix
	SetScale/P y,yMin-pad,StepSize,CMM_asymmMatrix
	SetScale d 0,0,"V", CMM_asymmMatrix

	// Symmetric matrix
	Variable	xN_symm = floor( (xAbsMax+pad+xAbsMax+pad)/StepSize+1 )
	Make/O/N=(xN_symm,yN) CMM_symmMatrix
	CMM_symmMatrix = 0
	SetScale/P x,-xAbsMax-pad,StepSize,CMM_symmMatrix
	SetScale/P y,yMin-pad,StepSize,CMM_symmMatrix
	SetScale d 0,0,"V", CMM_symmMatrix

	//// CELL-CENTERED COORDINATES
	NVAR		xMin = CMM_xMin_cent
	NVAR		xMax = CMM_xMax_cent
	NVAR		yMin = CMM_yMin_cent
	NVAR		yMax = CMM_yMax_cent
	NVAR		xAbsMax = CMM_xAbsMax_cent
	NVAR		yAbsMax = CMM_yAbsMax_cent
	// Asymmetric matrix
	xN = floor( (xMax+pad-xMin+pad)/StepSize+1 )
	yN = floor( (yMax+pad-yMin+pad)/StepSize+1 )
	Make/O/N=(xN,yN) CMM_asymmMatrix_cent
	CMM_asymmMatrix_cent = 0
	SetScale/P x,xMin-pad,StepSize,CMM_asymmMatrix_cent
	SetScale/P y,yMin-pad,StepSize,CMM_asymmMatrix_cent
	SetScale d 0,0,"V", CMM_asymmMatrix_cent

	// Symmetric matrix
	xN_symm = floor( (xAbsMax+pad+xAbsMax+pad)/StepSize+1 )
	Make/O/N=(xN_symm,yN) CMM_symmMatrix_cent
	CMM_symmMatrix_cent = 0
	SetScale/P x,-xAbsMax-pad,StepSize,CMM_symmMatrix_cent
	SetScale/P y,yMin-pad,StepSize,CMM_symmMatrix_cent
	SetScale d 0,0,"V", CMM_symmMatrix_cent

	//// DISTORTED COORDINATES
	NVAR		xMin = CMM_xMin_dist
	NVAR		xMax = CMM_xMax_dist
	NVAR		yMin = CMM_yMin_dist
	NVAR		yMax = CMM_yMax_dist
	NVAR		xAbsMax = CMM_xAbsMax_dist
	NVAR		yAbsMax = CMM_yAbsMax_dist
	// Asymmetric matrix
	xN = floor( (xMax+pad-xMin+pad)/StepSize+1 )
	yN = floor( (yMax+pad-yMin+pad)/StepSize+1 )
	Make/O/N=(xN,yN) CMM_asymmMatrix_dist
	CMM_asymmMatrix_dist = 0
	SetScale/P x,xMin-pad,StepSize,CMM_asymmMatrix_dist
	SetScale/P y,yMin-pad,StepSize,CMM_asymmMatrix_dist
	SetScale d 0,0,"V", CMM_asymmMatrix_dist

	// Symmetric matrix
	xN_symm = floor( (xAbsMax+pad+xAbsMax+pad)/StepSize+1 )
	Make/O/N=(xN_symm,yN) CMM_symmMatrix_dist
	CMM_symmMatrix_dist = 0
	SetScale/P x,-xAbsMax-pad,StepSize,CMM_symmMatrix_dist
	SetScale/P y,yMin-pad,StepSize,CMM_symmMatrix_dist
	SetScale d 0,0,"V", CMM_symmMatrix_dist

End
	
/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Make gamma-corrected LUT

Function CMM_updateGammaProc(sva) : SetVariableControl
	STRUCT WMSetVariableAction &sva
	
	NVAR		CMM_HeatmapGamma

	switch( sva.eventCode )
		case 1: // mouse up
		case 2: // Enter key
		case 3: // Live update
			Variable dval = sva.dval
			String sval = sva.sval
			CMM_makeGammaCorrectedLUT(CMM_HeatmapGamma)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function CMM_makeGammaCorrectedLUT(theGamma)
	Variable	theGamma

	ColorTab2Wave BlueHot256
	WAVE		M_colors
	Variable	nColorsIn = DimSize(M_colors,0)
	Variable	nColorsOut = 2^12
	Make/O/N=(nColorsOut,3) CMM_LUT
	Variable	i,j
	i = 0
	do
		j = floor( (i/nColorsOut)^(theGamma)*nColorsIn )
		CMM_LUT[i][0] = M_colors[j][0]
		CMM_LUT[i][1] = M_colors[j][1]
		CMM_LUT[i][2] = M_colors[j][2]
		i += 1
	while(i<nColorsOut)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot the cortical cross section

Function CMM_plotCrossSectionX()

	WAVE		CMM_CrossSectionX
	
	Variable	blackBack = 1

	doWindow/K CMM_CrossSectionXGraph	
	Display /W=(56,100,512,175) CMM_CrossSectionX as "Cross section X"
	doWindow/C CMM_CrossSectionXGraph	
	ModifyGraph mode=7
	ModifyGraph rgb=(0,0,0)
	ModifyGraph hbFill=2
	ModifyGraph usePlusRGB=1
	ModifyGraph plusRGB=(52428,52428,52428)
	SetAxis/A bottom
	
	if (blackBack)
		ModifyGraph gbRGB=(0,0,0),wbRGB=(0,0,0)
		ModifyGraph plusRGB=(52428,1,1)
		ModifyGraph rgb=(65535,65535,65535)
	endif

	// Add postsynaptic cell
	WAVE		CMM_postY_meanX_dist
	AppendToGraph CMM_postY_meanX_dist
	ModifyGraph rgb(CMM_postY_meanX_dist)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_meanX_dist)=8							
	ModifyGraph mode(CMM_postY_meanX_dist)=3,marker(CMM_postY_meanX_dist)=60
	ModifyGraph mrkThick(CMM_postY_meanX_dist)=1,useMrkStrokeRGB(CMM_postY_meanX_dist)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_meanX_dist)=(0,26611,65535)

	ModifyGraph margin(left)=-1,margin(bottom)=10,margin(top)=4,margin(right)=-1
	ModifyGraph noLabel(left)=2,axThick=0//(left)=0
	ModifyGraph nticks=0
	ModifyGraph noLabel=2
	ModifyGraph standoff=0
	ModifyGraph axThick=0

//	if (blackBack)
//		ModifyGraph tick(left)=2,nticks(left)=3,minor(left)=1,noLabel(left)=0,axThick(left)=1,axRGB(left)=(65535,65535,65535),tlblRGB(left)=(65535,65535,65535),alblRGB(left)=(65535,65535,65535)
//		ModifyGraph lblPosMode(left)=4,lblPos(left)=10,lblLatPos(left)=10,tlOffset(left)=-20
//		Label left "\\u#2"
//	endif

	// Add column lines
	NVAR		CMM_columnWidth
	SetDrawLayer UserFront
	Variable	fontSize = 10
	SetDrawEnv xcoord= bottom,ycoord= prel,fname= "Arial",fstyle= 3,fsize= fontSize
	if (blackBack)
		SetDrawEnv textrgb= (65535,65535,65535)
	endif
	SetDrawEnv textxjust= 1,textyjust= 2
	DrawText 0,0,"Column"
	SetDrawLayer UserFront
	SetDrawEnv xcoord= bottom,ycoord= prel,linefgc= (0,0,0),linethick= 1,dash= 1
	if (blackBack)
		SetDrawEnv linefgc=(65535,65535,65535)
	endif
	DrawLine -CMM_columnWidth/2,0,-CMM_columnWidth/2,1
	SetDrawEnv xcoord= bottom,ycoord= prel,linefgc= (0,0,0),linethick= 1,dash= 1
	if (blackBack)
		SetDrawEnv linefgc=(65535,65535,65535)
	endif
	DrawLine CMM_columnWidth/2,0,CMM_columnWidth/2,1
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Plot the cortical cross section

Function CMM_plotCrossSectionY()

	WAVE		CMM_CrossSectionY

	Variable	blackBack = 1

	doWindow/K CMM_CrossSectionYGraph	
	Display /W=(64,100,64+85,508) CMM_CrossSectionY as "Cross section Y"
	doWindow/C CMM_CrossSectionYGraph	
	ModifyGraph mode=7
	ModifyGraph rgb=(0,0,0)
	ModifyGraph hbFill=2
	ModifyGraph usePlusRGB=1
	ModifyGraph plusRGB=(52428,52428,52428)
	SetAxis/A/R bottom

	if (blackBack)
		ModifyGraph gbRGB=(0,0,0),wbRGB=(0,0,0)
		ModifyGraph plusRGB=(52428,1,1)
		ModifyGraph rgb=(65535,65535,65535)
	endif

	// Add postsynaptic cell
	WAVE		CMM_postY_scatterY_dist,CMM_postY_scatterX_dist		// scatterY and corresponding x-axis wave
	WAVE		CMM_postY_mean_dist,CMM_postY_SEM_dist				// mean ± SEM
	// Postsyn cells
	AppendToGraph CMM_postY_scatterX_dist vs CMM_postY_scatterY_dist
	ModifyGraph rgb(CMM_postY_scatterX_dist)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_scatterX_dist)=3
	ModifyGraph mode(CMM_postY_scatterX_dist)=3,marker(CMM_postY_scatterX_dist)=60
	ModifyGraph mrkThick(CMM_postY_scatterX_dist)=0.5,useMrkStrokeRGB(CMM_postY_scatterX_dist)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_scatterX_dist)=(0,26611/2,65535/2)

	// Postsyn cell
	Duplicate/O CMM_postY_mean_dist,CMM_postY_meanX_dist
	CMM_postY_meanX_dist = CMM_postY_scatterX_dist[0]
	AppendToGraph CMM_postY_meanX_dist vs CMM_postY_mean_dist
	ModifyGraph rgb(CMM_postY_meanX_dist)=(65535,65535,65535)
	ModifyGraph msize(CMM_postY_meanX_dist)=8							
	ModifyGraph mode(CMM_postY_meanX_dist)=3,marker(CMM_postY_meanX_dist)=60
	ModifyGraph mrkThick(CMM_postY_meanX_dist)=1,useMrkStrokeRGB(CMM_postY_meanX_dist)=1
	ModifyGraph mrkStrokeRGB(CMM_postY_meanX_dist)=(0,26611,65535)
	ErrorBars/RGB=(0,26611,65535) CMM_postY_meanX_dist X,wave=(CMM_postY_SEM_dist,CMM_postY_SEM_dist)

//	ModifyGraph margin(left)=27,margin(bottom)=10,margin(top)=4,margin(right)=30
	ModifyGraph margin(left)=-1,margin(bottom)=10,margin(top)=4,margin(right)=-1
	
	doUpdate

	ModifyGraph swapXY=1
	ModifyGraph noLabel(bottom)=2,axThick(bottom)=0

	ModifyGraph nticks=0
	ModifyGraph noLabel=2
	ModifyGraph standoff=0
	ModifyGraph axThick=0

	// Add layer lines
	WAVE		wLayerOffs
	WAVE/T		wLayerSourceLabels
	Variable	fontSize = 10
	Variable	n = numpnts(wLayerOffs)
	Variable	i
	i = 0
	do
		SetDrawLayer UserFront
		SetDrawEnv xcoord= prel,ycoord= left,dash= 11
		if (blackBack)
			SetDrawEnv linefgc= (65535,65535,65535)
		endif
		DrawLine 0,wLayerOffs[i],1,wLayerOffs[i]
		SetDrawEnv xcoord= prel,ycoord= left,textyjust= 2,fname= "Arial",fstyle= 3,fsize=fontSize//, textrgb= (65535,65535,65535)
		if (blackBack)
			SetDrawEnv textrgb= (65535,65535,65535)
		endif
		DrawText 0,wLayerOffs[i],wLayerSourceLabels[i+1]
		if (i==0)
			SetDrawEnv xcoord= prel,ycoord= left,textyjust= 0,fname= "Arial",fstyle= 3,fsize=fontSize//, textrgb= (65535,65535,65535)
			if (blackBack)
				SetDrawEnv textrgb= (65535,65535,65535)
			endif
			DrawText 0,wLayerOffs[i],wLayerSourceLabels[0]
		endif
		i += 1
	while(i<n)
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Add to the cortical cross section

Function CMM_AddToCrossSection(cellX,cellY,UseAmp,Resp)
	WAVE		cellX
	WAVE		cellY
	WAVE		UseAmp
	WAVE		Resp
	
	WAVE		CMM_CrossSectionX
	WAVE		CMM_CrossSectionY

	NVAR		gaussDiam = CMM_gaussDiam
	NVAR		fillScale = CMM_fillScale
	NVAR		CMM_columnWidth

	Variable	xNow,yNow,aNow
	Variable	pNow,qNow,paNow,qaNow
	Variable	p1,p2,q1,q2

	Variable	n = numpnts(cellX)
	Variable	i
	i = 1			// Skip postsynaptic cell
	do
		if (Resp[i])
			xNow = cellX[i]
			yNow = cellY[i]
			aNow = UseAmp[i]
			// Horizontal cross section
			CMM_CrossSectionX += aNow*exp(-((x-xNow)/ (gaussDiam /(2*sqrt(ln(2)))) )^2)
			// Vertical cross section
			if (abs(xNow)<CMM_columnWidth/2)	// For y, only use points within the column
				CMM_CrossSectionY += aNow*exp(-((x-yNow)/ (gaussDiam /(2*sqrt(ln(2)))) )^2)	// don't be fooled by the 'x', this is still y!
			endif
		endif
		i += 1
	while(i<n)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the heatmap of connected cells
//// Suffix can be either "" or "_cent", so that both the regular and the cell-centered maps

Function CMM_AddToMatrices(cellX,cellY,UseAmp,Resp,Suffix)
	WAVE		cellX
	WAVE		cellY
	WAVE		UseAmp
	WAVE		Resp
	String		Suffix					// underscore has to be in the string so that "" can denote absolute

	NVAR		xMin = $("CMM_xMin"+Suffix)
	NVAR		xMax = $("CMM_xMax"+Suffix)
	NVAR		yMin = $("CMM_yMin"+Suffix)
	NVAR		yMax = $("CMM_yMax"+Suffix)
	
	NVAR		gaussDiam = CMM_gaussDiam
	NVAR		fillScale = CMM_fillScale
	
	WAVE		asymmMatrix = $("CMM_asymmMatrix"+Suffix)		// medial side to the left
	WAVE		symmMatrix = $("CMM_symmMatrix"+Suffix)			// apply mirror image too -- don't care about where medial side is
	
	Variable	xNow,yNow,aNow
	Variable	pNow,qNow,paNow,qaNow
	Variable	p1,p2,q1,q2

	Variable	n = numpnts(cellX)
	Variable	i
	i = 1			// Skip postsynaptic cell
	do
		if (Resp[i])

			xNow = cellX[i]
			yNow = cellY[i]
			aNow = UseAmp[i]

			// Asymmetric heatmap
			pNow = (xNow - DimOffset(asymmMatrix, 0))/DimDelta(asymmMatrix,0)
			qNow = (yNow - DimOffset(asymmMatrix, 1))/DimDelta(asymmMatrix,1)
			paNow = 1/DimDelta(asymmMatrix,0)*gaussDiam /(2*sqrt(ln(2)))		// Conversion factor is so Gaussian half-width matches stated diameter gaussDiam
			qaNow = 1/DimDelta(asymmMatrix,1)*gaussDiam /(2*sqrt(ln(2)))
			p1 = Round(pNow-paNow*fillScale)
			p2 = Round(pNow+paNow*fillScale)
			q1 = Round(qNow-qaNow*fillScale)
			q2 = Round(qNow+qaNow*fillScale)
			asymmMatrix[p1,p2][q1,q2] += aNow*exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))
			
			// Symmetric heatmap
			pNow = (xNow - DimOffset(symmMatrix, 0))/DimDelta(symmMatrix,0)
			qNow = (yNow - DimOffset(symmMatrix, 1))/DimDelta(symmMatrix,1)
			paNow = 1/DimDelta(symmMatrix,0)*gaussDiam /(2*sqrt(ln(2)))
			qaNow = 1/DimDelta(symmMatrix,1)*gaussDiam /(2*sqrt(ln(2)))
			p1 = Round(pNow-paNow*fillScale)
			p2 = Round(pNow+paNow*fillScale)
			q1 = Round(qNow-qaNow*fillScale)
			q2 = Round(qNow+qaNow*fillScale)
			symmMatrix[p1,p2][q1,q2] += aNow*exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))
			// Create mirror image too
			xNow *= -1
			pNow = (xNow - DimOffset(symmMatrix, 0))/DimDelta(symmMatrix,0)
			p1 = Round(pNow-paNow*fillScale)
			p2 = Round(pNow+paNow*fillScale)
			symmMatrix[p1,p2][q1,q2] += aNow*exp(-( ((p-pNow)/paNow)^2+((q-qNow)/qaNow)^2))

		endif
		i += 1
	while(i<n)

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Set the path string

Function CMM_SetSourcePath()

	SVAR		CMM_PathStr
	String		dummyStr

	PathInfo CMM_sourcePath
	if (V_flag)
		PathInfo/S CMM_sourcePath												// Default to this path if it already exists
	endif
	NewPath/O/Q/M="Chose the source path!" CMM_sourcePath
	PathInfo CMM_sourcePath
	if (V_flag)
		print "--- SETTING THE SOURCE PATH ---"
		print Date(),Time()
		CMM_PathStr = S_path[0,25]+" ... "+S_path[strlen(S_path)-32,strlen(S_path)-1]
		print "\t\t\""+S_path+"\""
	else
		print "ERROR! Path doesn't appear to exist!"
		CMM_PathStr = "<nul>"
	endif
	
End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the linear histogram

Function CMM_LinBinHist()

	WAVE		allUseAmp
	WaveStats/Q allUseAmp
	Variable	binSize = 0.2e-3
	Variable	nBins = Round(V_max/binSize)+1

	DoWindow/K CMM_Graph5
	JT_MakeHistSpecced("allUseAmp",0,binSize,nBins,"amplitude (mV)","EPSP histogram")
	DoWindow/C CMM_Graph5
	ModifyGraph mrkThick=1
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=1
	ModifyGraph lsize=1
	ModifyGraph fSize=10
	Label bottom "amplitude (mV)\\u#2"
	WaveStats/Q allUseAmp
	Legend/C/N=text0/J/F=0/B=1/X=0.00/Y=5.00 "\\f01EPSP histogram\\f00\rn = "+num2str(V_npnts)
	SetDrawLayer UserFront
	SetDrawEnv xcoord= bottom,dash= 11
	DrawLine V_avg,0,V_avg,1
	SetDrawEnv xcoord= bottom,fstyle= 3,textrot= 90,fsize= 9
	SetDrawEnv textxjust= 0, textyjust= 2
	DrawText V_avg,0,"mean"

End

/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create log-normal histogram

Function CMM_makeLogNormalHistogram(wSourceStr,wDestStr)
	String		wSourceStr
	String		wDestStr
	
	WAVE		CMM_nonLinBins						// Created outside function
	
	Variable	nBins = numpnts(CMM_nonLinBins)

	Make/O/N=(nBins) $(wDestStr)
	WAVE	wDest = $(wDestStr)
	WAVE	wSource = $(wSourceStr)
	Histogram/NLIN=CMM_nonLinBins wSource,wDest

	wDest[numpnts(wDest)] = {0}						// Add a zero bin so that wave numbers match up
	
End


/////////////////////////////////////////////////////////////////////////////////////////////////////////
//// Create the log histogram with the logNormal fit

Function CMM_logBinHist()

	WAVE		allUseAmp
	
	WaveStats/Q	allUseAmp
	Variable 	nBins
	Variable	div = 1.5
	Variable	theMax = V_max*div^2
	
	Variable	minTarget = 0.001e-3
	nBins = Ceil( ln(theMax/minTarget)/ln(div) )
	
	print		"nBins:",nBins
	print		"Log min:",theMax/div^nBins*1e3,"mV"

	// Create overall non-linear histogram
	Make/O/N=(nBins) CMM_nonLinBins
	CMM_nonLinBins = theMax/div^p
	Sort CMM_nonLinBins,CMM_nonLinBins
	CMM_makeLogNormalHistogram(nameofwave(allUseAmp),"nonLinHist")
	WAVE	nonLinHist
	Variable	TheSum = Sum(nonLinHist)				// Normalize histogram
	nonLinHist *= 100/TheSum

	// Create individual non-linear histograms
	SVAR		CMM_ExpList
	Variable	nExps = itemsInList(CMM_ExpList)
	String		currExp
	Variable i = 0
	do
		currExp = StringFromList(i,CMM_ExpList)
		CMM_makeLogNormalHistogram(currExp+"_UseAmp","nLH_"+currExp)
		WAVE		w = $("nLH_"+currExp)
		w *= 100/TheSum
		i += 1
	while(i<nExps)

	CMM_nonLinBins *= 1e3							// LAST: Convert bins to mV

	DoWindow/K CMM_Graph6
	Display as "Log EPSP Histogram"
	DoWindow/C CMM_Graph6
	AppendToGraph nonLinHist vs CMM_nonLinBins 
	i = 0
	do
		currExp = StringFromList(i,CMM_ExpList)
		AppendTograph $("nLH_"+currExp) vs CMM_nonLinBins
		i += 1
	while(i<nExps)
	ModifyGraph toMode=2			// Stack on next
	ModifyGraph toMode($("nLH_"+currExp))=0		// To avoid having last experiment stacking onto the curve fit below...
	ModifyGraph log(bottom)=1
	ModifyGraph mode=5
	ModifyGraph mrkThick=1
	ModifyGraph rgb=(33536,40448,47872)
	ModifyGraph hbFill=2
	ModifyGraph useBarStrokeRGB=0	// 1
	ModifyGraph lsize=1
	ModifyGraph fSize=10
	SetAxis/A/N=1 left
	Label left,"frequency (%)"
	Label bottom "amplitude (mV)\\u#2"
	CallColorizeTraces3()

	K0 = 0;CurveFit/Q/H="1000"/M=2/W=0 LogNormal, nonLinHist/X=CMM_nonLinBins/D
	ModifyGraph lstyle(fit_nonLinHist)=2,lsize(fit_nonLinHist)=2
	ModifyGraph rgb(fit_nonLinHist)=(0,0,0)	//,65535/2)
//	ModifyGraph offset(fit_nonLinHist)={0.5,0}	// Unsure about binsizes on a log axis, it seems like 0.5 is correct by eyeballing it
	RemoveFromGraph nonLinHist			// We need this to be present for the curve fit to work
	
	print "\ty0",K0
	print "\tA",K1
	print "\tx0",K2
	print "\twidth",K3

	WaveStats/Q allUseAmp
	String legStr = ""
	legStr += "\\f01EPSP histogram\\f00\r"
	legStr += "µ = "+num2str(Round(V_avg*1e5)/1e2)+" ± "+num2str(Round(V_SEM*1e5)/1e2)+" mV, "
	legStr += "n = "+num2str(V_npnts)+"\r"
	legStr += "x\B0\M = "+num2str(Round(k2*1e2)/1e2)+"\r"
	legStr += "σ = "+num2str(Round(k3/sqrt(2)*1e2)/1e2)+"\r"
	legStr += "max = "+num2str(Round(V_max*1e5)/1e2)+" mV\r"
	legStr += "min = "+num2str(Round(V_min*1e6)/1e3)+" mV\r"
	Legend/C/N=text0/A=LT/J/F=0/B=1/X=1.00/Y=0.00 legStr
	SetDrawEnv xcoord= bottom,dash= 11
	DrawLine V_avg*1e3,0,V_avg*1e3,1
	SetDrawEnv xcoord= bottom,fstyle= 3,textrot= 90,fsize= 9
	SetDrawEnv textxjust= 0, textyjust= 2
	DrawText V_avg*1e3,0,"mean"
	
	ModifyGraph nticks(left)=3,minor(left)=1
	
//	JT_ExpandTopGraph()			// Remove later

End

