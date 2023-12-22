# jScan
2-photon imaging and optomapping software that runs in Igor Pro v9 or higher.

Use jScan to acquire 2-photon imaging data, e.g., individual images, stacks, or linescans.

If you do not have any data acquisition boards on your computer, you can start this software up in demo mode, see pragma and comment on line 3 of code.

Briefly, use "Scan" to view your preparation, "Grab" to acquire an image, and "Loop" to repeat the same acquisition at timed intervals. Use "Make stack panel" followed by "Acquire stack" to grab a stack of images.

To use jScan for optomapping, acquire a single image plane with "Grab", click the "Make 2p zap panel", use "Pick source" popup to choose the imaging channel, then use the top left "Auto" button to auto-detect cells in the field of view. Where the auto feature makes mistakes, you can Add, Move, or Drop individual cells. Then you click "Path" to create the beam path that stimulates the presynaptic cells. You use "Run 2p zap pattern" to run the 2p optomapping fly path, which is then repeated "maximum runs" number of times.

jScan uses Jesper's Tools (JespersTools_v03.ipf) as a library of repeatedly used function calls. Jesper's Tools are found the qMorph repository.

jScan is meant to be used in conjunction with "Multipatch 1019.ipf" (see separate repository) to acquire whole-cell electrophysiology data.

Optomapping data from individual postsyanptic cells can be analyzed with "CMap_v01.ipf" (this repository). Data from CMap is exported to a folder for postsynaptic cells of the same class, e.g. basket cells or Martinotti cells.

Optomapping data across several cells of the same category can then be analyzed with "CMetaMap_v02.ipf" (this repository)

2-photon imaging data such as line scans can be analyzed with "LineScanAnalysis12.ipf" (see separate repository). Despite its name, LineScanAnalysis12 also analyzes frame scans and movies. LineScanAnalysis12 will also analyze data from MBF Bioscience's ScanImage 2-photon imaging software.
