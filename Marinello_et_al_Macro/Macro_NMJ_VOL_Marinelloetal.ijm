requires("1.53f");
//MAIN CODE

// Choice of Image Type
//Get Images Directory and number of junction folders


Imdir=getDirectory("Image Junction Folder");
jctn = getFileList(Imdir);

Nbj=lengthOf(jctn);

//Define a saving directory
pathsave=getDirectory("Saving Folder");

types = newArray("Nikkon nd2","Leica lif or Zeiss czi","TIFF");
		Dialog.create("Image Type");
		Dialog.addMessage("Select the Type of Images");
		Dialog.addChoice("Images", types);
		Dialog.show();
TypeIm=Dialog.getChoice();

	if (TypeIm=="Leica lif or Zeiss czi")
	{
		TypeIm="Leica lif";
	}

//Use of the functions (at the end of the code) for extracting pixel information from images or dialog boxes
	
ChanPix=selectChannelandPix(TypeIm);
channel=ChanPix[0];
xypix=ChanPix[1];
zstep=ChanPix[2];

//Batchmode true to improve processing speed 
setBatchMode(true);

for (i = 0; i < Nbj ; i++) 
{
	
	// Open stack of the junction images 
	// according to the Image Type
		
	if (TypeIm == "Nikkon nd2") 
		{
		ListImJcn=getFileList(Imdir);
		open(Imdir+ListImJcn[i]);
	
		extractChannel_bioFormat(channel);
		getVoxelSize(width, height, depth, unit);
		xypix=width;
		zstep=depth;	
		}

		
	else if (TypeIm == "Leica lif") 
		{
		ListImJcn=getFileList(Imdir);
		Junction=Imdir+ListImJcn[i];
		run("Bio-Formats Importer", "open="+Junction+" autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
		extractChannel_bioFormat(channel);
		getVoxelSize(width, height, depth, unit);
		xypix=width;
		zstep=depth;
		}

	else 
		{	
		ListImJcn=getFileList(Imdir+jctn[i]);	
		Junction=Imdir+jctn[i];
		
		run("Image Sequence...", "dir="+Junction+" sort");
		run("Set Scale...", "distance=1 known="+xypix+" pixel=1 unit=um");
		extractChannel_RGB(channel);
		}
		
	//-----------------------------
	//Quantification of BTX staining Volume
	
	//Positionning in the middle of the stack for correct thresholding
	selectWindow("stack");
	Midslice=nSlices/2+1;
	setSlice(Midslice);

	//Otsu Thresholding of the midslice
	setAutoThreshold("Otsu");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Otsu background=Dark");
	run("Invert","stack");
	run("Dilate","stack");
	run("Duplicate...", "duplicate");
	rename("stack1");
	selectWindow("stack");
	
	// Analyse of detected surfaces
	run("Set Measurements...", "area mean redirect=None decimal=3");
	run("Analyze Particles...", "size=20-Infinity pixel show=Masks display exclude stack");


	pathjctn=pathsave+jctn[i]+"/";
	File.makeDirectory(pathjctn);

	//Saving the image of the segemented junction

	selectWindow("Mask of stack");
	saveAs("Tiff", pathjctn + "Drawing" +jctn[i]+".tif");
	selectWindow("Drawing"+jctn[i]+".tif");
	close();
	selectWindow("Results");

		//Calculating junction volume by summing all surfaces detected, and multiplying by zstep.
		
		n=getValue("results.count");
		a=0;
		post=0;
		for(k=0; k<n; k=k+1)
 			{
			post=getResult("Area",k) + a;
			a=post;
			}

		voljunc=post*zstep;

	//Saving the results
	
	selectWindow("Results");
	saveAs("Results", pathjctn + "Results_Volume_" + jctn[i] + ".csv");
	run("Close");
	
	// Calculation of Z maximum projection
	selectWindow("stack1");
	run("Z Project...", "projection=[Max Intensity]");
	selectWindow("MAX_stack1");
	
	// Measurement of maximum projection surface area
	run("Analyze Particles...", "size=200-Infinity pixel show=[Bare Outlines] display exclude");
	
	// Saving maximum projection and results
	selectWindow("MAX_stack1");
	saveAs("Tiff", pathjctn + "Maxproj" +jctn[i]+".tif");
	selectWindow("Drawing of MAX_stack1");
	saveAs("Tiff", pathjctn + "Drawing_Maxproj" +jctn[i]+".tif");
	run("Close");
	selectWindow("Results");

	// Calculating the endplate surface area by summing the surface of all detected elements in the max projection of  staining. 
	
	n=getValue("results.count");
		a=0;
		endp=0;
		for(k=0; k<n; k=k+1)
 			{
			endp=getResult("Area",k) + a;
			a=endp;
			}

	// Saving the results
	selectWindow("Results");
	saveAs("Results", pathjctn + "Results_MIPsurface_" + jctn[i] + ".csv");
	run("Close");
	selectWindow("stack1");
	close();

	// Calculation of Tortuosity and saving tortuosity results
	selectWindow("Maxproj"+jctn[i]+".tif");
	run("Tortuosity", "mask=[Maxproj"+jctn[i]+".tif] distances=[Borgefors (3,4)] sub-sampling=1");
	selectWindow("Maxproj"+jctn[i]+"-tortuosity");
	
	tort=getResult("Tortuosity", 0);
	
	saveAs("Results",pathjctn + "Results_Tortuosity_" + jctn[i] + ".csv");
	run("Close");
	selectWindow("stack");
	close();
	selectWindow("Maxproj"+jctn[i]+".tif");
	close();

	// Display the results for each junction 
	print(jctn[i]," : PostSynaptic Volume (um^3) : ",voljunc, "Endplate Area (um^2) : ", endp,"Tortuosity : ",tort);
	run("Close All");

	
}

	// Saving the displayed log window. 
	selectWindow("Log");
	saveAs("Text",pathsave+"Log_analysis.csv");

//FUNCTIONS 

// Function to extract the channel in which the staining of interest is, and the size of the pixel. 
function selectChannelandPix(TypeIm) {
		
		
		if (TypeIm == "Nikkon nd2") 
			{
				Dialog.create("Channel");
			Dialog.addMessage("Select the channel corresponding to staining of interest");
			Dialog.addString("C1 ; C2 ; C3","C2");
			Dialog.show();
				channel=Dialog.getString();
				xypix=0;
				zstep=0;
			}
		
		else if (TypeIm == "Leica lif") 
			{
				Dialog.create("Channel");
			Dialog.addMessage("Select the channel corresponding to staining of interest");
			Dialog.addString("C1 ; C2 ; C3","C2");
			Dialog.show();
				channel=Dialog.getString();	
				xypix=0;
				zstep=0;
			}
		
		else 
			{
			RGB=newArray("G","R","B");	
			Dialog.create("Junction number");
			Dialog.addMessage("Select the RGB channel corresponding to staining of interest");
			Dialog.addChoice("Channel",RGB);
			Dialog.addMessage("Indicate size of pixel in µm");
			Dialog.addString("XY pixel size","0.072");
			Dialog.addString("Z step","0.5");
			Dialog.show();
			channel=Dialog.getChoice();
			xypix=Dialog.getString();
			zstep=Dialog.getString();
			}

	results = newArray(channel,xypix,zstep);
	
	return results; 
}


//----------------------------------------------------------------------------------

// Function to extract the correct channel of the images in .lif .czi or .nd2

function extractChannel_bioFormat(channel) {
	
getDimensions(width, height, chan, slices, frames);

	if (chan==1) 
		{
			rename(stack);
		}
	
	else if (chan==2) 
		{
		rename("stack");
		run("Split Channels");
		
			if (channel=="C1")
				{
				selectWindow("C2-stack");
				run("Close");
				selectWindow("C1-stack");
				rename("stack");
				
				}
			else if (channel=="C2")
				{
				selectWindow("C1-stack");
				run("Close");
				selectWindow("C2-stack");
				rename("stack");
				}
			else
				{ 	
				print("ERROR !! The Selected Channel is not correct"); 
				break; 
				}
		}

	else if (chan==3)
		{	
		rename("stack");
		run("Split Channels");
			
			if (channel=="C1")
				{
				selectWindow("C2-stack");
				run("Close");
				selectWindow("C3-stack");
				run("Close");
				selectWindow("C1-stack");
				rename("stack");
				}
				
			else if (channel=="C2")
				{
				selectWindow("C3-stack");
				run("Close");
				selectWindow("C1-stack");
				run("Close");
				selectWindow("C2-stack");
				rename("stack");
				}

			else if (channel=="C3")
				{
				selectWindow("C1-stack");
				run("Close");
				selectWindow("C2-stack");
				run("Close");
				selectWindow("C3-stack");
				rename("stack");
				}

			else 
					{ 	
					print("ERROR !! The Selected Channel is not correct"); 
					break; 
					}
		}

	else if (chan==4)	
		{
			if (channel=="C1")
				{
				selectWindow("C2-stack");
				run("Close");
				selectWindow("C3-stack");
				run("Close");
				selectWindow("C4-stack");
				run("Close");
				selectWindow("C1-stack");
				rename("stack");
				}
				
			else if (channel=="C2")
				{
				selectWindow("C1-stack");
				run("Close");
				selectWindow("C3-stack");
				run("Close");
				selectWindow("C4-stack");
				run("Close");
				selectWindow("C2-stack");
				rename("stack");
				}
				
			else if (channel=="C3")
				{
				selectWindow("C2-stack");
				run("Close");
				selectWindow("C1-stack");
				run("Close");
				selectWindow("C4-stack");
				run("Close");
				selectWindow("C3-stack");
				rename("stack");
				}
				
			else if (channel=="C4")
				{
				selectWindow("C2-stack");
				run("Close");
				selectWindow("C1-stack");
				run("Close");
				selectWindow("C3-stack");
				run("Close");
				selectWindow("C4-stack");
				rename("stack");
				}
			
			else 
				{ 	
				print("ERROR !! The Selected Channel is not correct"); 
				break; 
				}
		}
}

//-----------------------------------------------------------------------------------

// Function to extract the RGB channel of interest for Tiff Files

function extractChannel_RGB(channel) {
		
		if (channel=="G") 
			{
			rename("stack");
			run("Split Channels");
			selectWindow("stack (blue)");
			close();
			selectWindow("stack (red)");
			close();
			selectWindow("stack (green)");
			rename("stack");
			}
		else if (channel=="B") 
			{
			rename("stack");
			run("Split Channels");
			selectWindow("stack (green)");
			close();
			selectWindow("stack (red)");
			close();
			selectWindow("stack (blue)");
			rename("stack");
			}
		else
			{
			rename("stack");
			run("Split Channels");
			selectWindow("stack (blue)");
			close();
			selectWindow("stack (green)");
			close();
			selectWindow("stack (red)");
			rename("stack");
			}
}


//-----------------------------------------------------------------------------------
