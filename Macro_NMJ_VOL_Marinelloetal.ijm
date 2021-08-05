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

	
	
ChanPix=selectChannelandPix(TypeIm);
channel=ChanPix[0];
xypix=ChanPix[1];
zstep=ChanPix[2];

//Batchmode true to improve processing speed 
setBatchMode(true);

for (i = 0; i < Nbj ; i++) 
{
	
	// Open stack of the junction images
	j=i+1;
	
	
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
		Junction=Imdir+jctn[i]+ListImJcn[0];
	
		
		run("Image Sequence...", "open=[Junction] sort");
		run("Set Scale...", "distance=1 known="+xypix+" pixel=1 unit=um");
		extractChannel_RGB(channel);
		}
		
	//-----------------------------
	
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
	run("Analyze Particles...", "size=20-Infinity pixel show=[Bare Outlines] display exclude stack");

	//Saving the image of the segemented junction, and the results of detected surfaces per image
	pathjctn=pathsave+"Junction"+j+"/";
	File.makeDirectory(pathjctn);
	
	selectWindow("Drawing of stack");
	saveAs("Tiff", pathjctn + "DrawingJunction" +j+".tif");
	selectWindow("DrawingJunction"+j+".tif");
	close();
	selectWindow("Results");

		//Calcul du Volume de la jonction
		
		n=getValue("results.count");
		a=0;
		post=0;
		for(k=0; k<n; k=k+1)
 			{
			post=getResult("Area",k) + a;
			a=post;
			}

		voljunc=post*zstep;
	
	selectWindow("Results");
	saveAs("Results", pathjctn + "Results_Volume_Junction" + j + ".csv");
	run("Close");
	
	// Calculation of Z maximum projection
	selectWindow("stack1");
	run("Z Project...", "projection=[Max Intensity]");
	selectWindow("MAX_stack1");
	// Measurement of maximum projection surface area
	run("Analyze Particles...", "size=20-Infinity pixel show=[Bare Outlines] display exclude");
	// Saving maximum projection and results
	selectWindow("MAX_stack1");
	saveAs("Tiff", pathjctn + "Maxproj" +j+".tif");
	selectWindow("Drawing of MAX_stack1");
	saveAs("Tiff", pathjctn + "Drawing_Maxproj" +j+".tif");
	run("Close");
	selectWindow("Results");
	
	n=getValue("results.count");
		a=0;
		endp=0;
		for(k=0; k<n; k=k+1)
 			{
			endp=getResult("Area",k) + a;
			a=post;
			}

	
	selectWindow("Results");
	saveAs("Results", pathjctn + "Results_MIPsurface_Junction" + j + ".csv");
	run("Close");
	selectWindow("stack1");
	close();

	// Calculation of Tortuosity and saving tortuosity results
	selectWindow("Maxproj"+j+".tif");
	run("Tortuosity", "mask=[Maxproj"+j+".tif] distances=[Borgefors (3,4)] sub-sampling=1");
	selectWindow("Maxproj"+j+"-tortuosity");
	
	tort=getResult("Tortuosity", 0);
	
	saveAs("Results",pathjctn + "Results_Tortuosity_Junction" + j + ".csv");
	run("Close");
	selectWindow("stack");
	close();
	selectWindow("Maxproj"+j+".tif");
	close();

	print("Junction ",j," : PostSynaptic Volume (um^3) : ",voljunc, "Endplate Area (um^2) : ", endp,"Tortuosity : ",tort);
	run("Close All");

	
}


	selectWindow("Log");
	saveAs("Text",pathsave+"Log_analysis.csv");

//FUNCTIONS 

function selectChannelandPix(TypeIm) {
		
		
		if (TypeIm == "Nikkon nd2") 
			{
				Dialog.create("Channel");
			Dialog.addMessage("Select the channel corresponding to staining of interest");
			Dialog.addString("C1 ; C2 ; C3","C1");
			Dialog.show();
				channel=Dialog.getString();
				xypix=0;
				zstep=0;
			}
		
		else if (TypeIm == "Leica lif") 
			{
				Dialog.create("Channel");
			Dialog.addMessage("Select the channel corresponding to staining of interest");
			Dialog.addString("C1 ; C2 ; C3","C1");
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
