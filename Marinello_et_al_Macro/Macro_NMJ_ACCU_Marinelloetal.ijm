requires("1.53f");
// MAIN CODE
// Choice of Image Type
// Get Images Directory and number of junction folders

Imdir=getDirectory("Image Junction Folder");
jctn = getFileList(Imdir);

Nbj=lengthOf(jctn);

// Define a saving directory
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


presyn=ChanPix[0];
chan_presyn=ChanPix[1];
postsyn=ChanPix[2];
chan_postsyn=ChanPix[3];
xypix=ChanPix[4];
zstep=ChanPix[5];

//Batchmode true to improve processing speed 
setBatchMode(true);

for (i = 0; i < Nbj ; i++) 
{

	// Open stack of the junction images according to the Image Type and extracting the presynaptic image stack (presyn) and the postsynaptic image stack (postsyn)
	
	if (TypeIm == "Nikkon nd2") 
		{
		ListImJcn=getFileList(Imdir);
		open(Imdir+ListImJcn[i]);
		extractChannel_bioFormat(chan_presyn,chan_postsyn);
		getVoxelSize(width, height, depth, unit);
		xypix=width;
		zstep=depth;
		}

		
	else if (TypeIm == "Leica lif") 
		{
		ListImJcn=getFileList(Imdir);
		Junction=Imdir+ListImJcn[i];
		run("Bio-Formats Importer", "open="+Junction+" autoscale color_mode=Default rois_import=[ROI manager] view=Hyperstack stack_order=XYCZT");
		extractChannel_bioFormat(chan_presyn,chan_postsyn);
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
		extractChannel_RGB(chan_presyn,chan_postsyn);		
		}


	selectWindow("stack_presyn");
	rename(presyn);
	selectWindow("stack_postsyn");
	rename(postsyn);



//----------------------------------------------------------------------
// Creating a directory for each junction
	
	pathjctn=pathsave+jctn[i];
	File.makeDirectory(pathjctn);
		
		// Calculating the volume of the postsynaptic part of the junction 
		
			selectWindow(postsyn);
			run("Duplicate...", "duplicate");
			name2=postsyn+"-2";
			rename(name2);
			
			selectWindow(postsyn);
			Midslice=nSlices/2+1;
			setSlice(Midslice);
		
			//Otsu Thresholding
			setAutoThreshold("Otsu");
			setOption("BlackBackground", false);
			run("Convert to Mask", "method=Otsu background=Dark");
			run("Invert","stack");
			run("Dilate","stack");
			// Analyzing surfaces	
			run("Set Measurements...", "area stack display redirect=None decimal=3");
			run("Analyze Particles...", "size=20-Infinity pixel show=Masks display exclude stack");
					
			// Summing all the surface area of detected surfaces = Volume of bungatoxin staining

			//Error message in case the signal is not automatically detected
			R=isOpen("Results");
			if (R==0) 
			{
				print("PostSynaptic signal is too low to be processed automatically.");
			}
			else 
			{
				//Calculating presynaptic volume by summing all surfaces detected, and multiplying by zstep.
				
				n=getValue("results.count");
				post=0;
				for(k=0; k<n; k=k+1)
		 			{
					post=getResult("Area",k) + post;
					}

				//Saving the results
					
			selectWindow("Results");
			saveAs("Results", pathjctn + File.separator + "Results_Volume_" + postsyn + "_" + jctn[i] + ".csv");
			selectWindow("Results");
			run("Close");

//----------------------------------------------------
	// Automatic CROP around the junction

	// Detection of all the surfaces from the max projection and creation a combined ROI 
	selectWindow(name2);
	run("Z Project...", "projection=[Max Intensity]");
	selectWindow("MAX_"+name2);
	setAutoThreshold("Otsu");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Invert");
	run("Median...", "radius=2");
	roiManager("reset");
	run("Analyze Particles...", "size=2-1000 add");
	combineroi();
	
	selectWindow(name2);
	n=roiManager("count");
	roiManager("Select", n-1);
	run("Crop");
	rename(postsyn);

	// Croping around the combined ROI for the postsynaptic stack and saving the stack
	
	selectWindow("Mask of "+postsyn);
	n=roiManager("count");
	roiManager("Select", n-1);
	run("Crop");
	saveAs("Tiff", pathjctn + File.separator + "Drawing_" + postsyn + "_" +jctn[i]+".tif");
	selectWindow("Drawing_"+postsyn+"_"+jctn[i]+".tif");
	run("Close");

	// Croping around the combined ROI for the presynatic stack and saving the stack
	
	selectWindow(presyn);
	roiManager("select", n-1);
	run("Crop");
	rename(presyn);
	run("Select None");
	
	selectWindow("stackMax");
	run("Z Project...", "projection=[Max Intensity]");
	selectWindow("MAX_stackMax");
	roiManager("select", n-1);
	run("Crop");

		
	saveAs("Tiff", pathjctn + File.separator + "Maxproj_crop_"+jctn[i]+".tif");
	selectWindow("Maxproj_crop_"+jctn[i]+".tif");
	run("Close");
	run("Clear Results");

	
	// Positionning in the middle of presynaptic tack for thresholding
	selectWindow(presyn);
	setSlice(Midslice);

	//Otsu Thresholding

		setAutoThreshold("Otsu");
		getThreshold(lower,upper);
		// Condition that avoid the Otsu threshold to threshold noise. If the signal is to weak, it is not processed. 
		T=maxOf(upper,8);
		setThreshold(0, T);
		setOption("BlackBackground", false);
		run("Convert to Mask", "method=Otsu background=Dark");
		run("Invert","stack");
		run("Dilate","stack");
		
		
		//Analysis of detected surfaces
		run("Analyze Particles...", "size=20-Infinity pixel show=Masks display exclude stack");
		//Saving the detected surfaces contour
		selectWindow("Mask of "+presyn);
		saveAs("Tiff", pathjctn + File.separator + "Drawing_"+presyn+"_" +jctn[i]+".tif");
		selectWindow("Drawing_"+presyn+"_"+jctn[i]+".tif");
		run("Close");
	
	// Summing all the surface area of detected surfaces = Volume of postsynaptic staining
	Res=isOpen("Results");
	if (Res==1) 
	{
	selectWindow("Results");
		n=getValue("results.count");
		pre=0;
		for(p=0; p<n; p=p+1)
 			{
			pre=getResult("Area",p) + pre;
			}
			saveAs("Results", pathjctn + File.separator + "Results_Volume_"+presyn+"_" + jctn[i] + ".csv");
			run("Close");
	 }
	 else { pre=0;}
	 
	//Calculation of presynaptic accumulation by making the ratio between presynaptic volume and postsynaptic volume
	
	Ratio=pre/post*100;
	
	selectWindow(postsyn);
	run("Close");
	//selectWindow(presyn);
	run("Close");

	//Calculation of actual volume in µm^3 
	prev=pre*zstep;
	postv=post*zstep;
	
	//Results Display
	

		print(jctn[i]," : Presynaptic Volume (um^3) : ",prev, "Postsynaptic Volume (um^3) : ", postv,"Ratio Accu : ",Ratio);
	}
		run("Close All");
	
}
	//Saving the final results of volumes and accumulation. 
	selectWindow("Log");
	saveAs("Text",pathsave+"Log_analysis.csv");




//FUNCTIONS -----------------------------------------------------------------------------------------
// Function to extract the channel in which the staining of interest is, and the size of the pixel. 

function selectChannelandPix(TypeIm) {
		
		
		if (TypeIm == "Nikkon nd2") 
			{
				Dialog.create("Channel");
			Dialog.addMessage("Select the label and channel corresponding to presynaptic and postsynaptic staining (C1, C2, C3 or C4)");
			Dialog.addString("presynaptic label","SV2");
			Dialog.addString("presynaptic channel","C3");
			Dialog.addString("postsynaptic label","BTX");
			Dialog.addString("postsynaptic channel","C2");
			Dialog.show();
				presyn=Dialog.getString();
				chan_presyn=Dialog.getString();
				postsyn=Dialog.getString();
				chan_postsyn=Dialog.getString();
				xypix=0;
				zstep=0;
			}
		
		else if (TypeIm == "Leica lif") 
			{
				Dialog.create("Channel");
			Dialog.addMessage("Select the label and channel corresponding to presynaptic and postsynaptic staining (C1, C2 or C3)");
			Dialog.addString("presynaptic label","SV2");
			Dialog.addString("presynaptic channel","C3");
			Dialog.addString("postsynaptic label","BTX");
			Dialog.addString("postsynaptic channel","C2");
			Dialog.show();
				presyn=Dialog.getString();
				chan_presyn=Dialog.getString();
				postsyn=Dialog.getString();
				chan_postsyn=Dialog.getString();
				xypix=0;
				zstep=0;
			}
		
		else 
			{
			Dialog.create("Staining Infos");
			Dialog.addMessage("Indicate label and RGB channel - R RED; G GREEN; B BLUE");
			Dialog.addString("Pre-synaptic label","SV2");
			Dialog.addString("Pre-synaptic Color","R");
			Dialog.addString("Post-synaptic label","BTX");
			Dialog.addString("Post-synaptic Color","G");
			Dialog.show();
				presyn=Dialog.getString();
				chan_presyn=Dialog.getString();
				postsyn=Dialog.getString();
				chan_postsyn=Dialog.getString();
			
			Dialog.create("Pixel Size infos");
			Dialog.addMessage("Indicate size of pixel in µm");
			Dialog.addString("XY pixel size","0.072");
			Dialog.addString("Z step","0.5");
			Dialog.show();
				xypix=Dialog.getString();
				zstep=Dialog.getString();
			}

	results = newArray(presyn,chan_presyn,postsyn,chan_postsyn,xypix,zstep);
	
	return results; 
}


//----------------------------------------------------------------------------------

// Function to extract the correct channel of the images in .lif .czi or .nd2

function extractChannel_bioFormat(chan_presyn,chan_postsyn) {
	
getDimensions(width, height, chan, slices, frames);

		rename("stack");
		run("Duplicate...", "title=stackMax duplicate");
		selectWindow("stack");
		run("Split Channels");
		
	 if (chan==2) 
		{
		
			if (chan_presyn=="C1")
				{
				selectWindow("C2-stack");
				rename("stack_postsyn");
				selectWindow("C1-stack");
				rename("stack_presyn");
				
				}
			else if (chan_presyn=="C2")
				{
				selectWindow("C1-stack");
				rename("stack_postsyn");
				selectWindow("C2-stack");
				rename("stack_presyn");
				}
			else
				{ 	
				print("ERROR !! The Selected Channel is not correct"); 
				break; 
				}
		}

	else if (chan==3)
		{	
		
			
			if (chan_presyn=="C1")
				{
				selectWindow("C1-stack");
				rename("stack_presyn");
					if (chan_postsyn=="C2")
					{
						selectWindow("C2-stack");
						rename("stack_postsyn");
					}
				
					else if (chan_postsyn=="C3")
					{ 
						selectWindow("C3-stack");
						rename("stack_postsyn");
					}
					else 
					{
					print("ERROR !! The Selected Channel is not correct"); 
					break; 
					}
					
				}
				
			else if (chan_presyn=="C2")
				{
				selectWindow("C2-stack");
				rename("stack_presyn");
					if (chan_postsyn=="C1")
					{
						selectWindow("C1-stack");
						rename("stack_postsyn");
					}
				
					else if (chan_postsyn=="C3")
					{ 
						selectWindow("C3-stack");
						rename("stack_postsyn");
					}
					else 
					{
					print("ERROR !! The Selected Channel is not correct"); 
					break; 
					}
				}
				

			else if (chan_presyn=="C3")
				{
				selectWindow("C3-stack");
				rename("stack_presyn");
					if (chan_postsyn=="C1")
					{
						selectWindow("C1-stack");
						rename("stack_postsyn");
					}
				
					else if (chan_postsyn=="C2")
					{ 
						selectWindow("C2-stack");
						rename("stack_postsyn");
					}
					else 
					{
					print("ERROR !! The Selected Channel is not correct"); 
					break; 
					}
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

function extractChannel_RGB(chan_presyn,chan_postsyn) {

		rename("stack");
		run("Duplicate...", "title=stackMax duplicate");
		selectWindow("stack");
		run("Split Channels");
	
		if (chan_presyn=="G") 
			{
			selectWindow("stack (green)");
			rename("stack_presyn");
			}
	
	else if (chan_presyn=="R") 
			{
			selectWindow("stack (red)");
			rename("stack_presyn");
			}

	else if (chan_presyn=="B") 
			{
			selectWindow("stack (blue)");
			rename("stack_presyn");
			}
	

		else 
			{ 	
			print("ERROR !! The Selected Channel is not correct"); 
			break; 
			}



		if (chan_postsyn=="G") 
			{
			selectWindow("stack (green)");
			rename("stack_postsyn");
			}
			
	else if (chan_postsyn=="R") 
			{
			selectWindow("stack (red)");
			rename("stack_postsyn");
			}

	else if (chan_postsyn=="B") 
			{
			selectWindow("stack (blue)");
			rename("stack_postsyn");
			}

	else 
			{ 	
			print("ERROR !! The Selected Channel is not correct"); 
			break; 
			}

}


//---------------------------------------------------------------------------------
//Function that combine different ROI into a ROI that is a logical OR of the initial ROIS

function combineroi()
{	
n=roiManager("count");
A=newArray(n);  
for (i=0; i<A.length; i++)
    { A[i] = i; }
roiManager('select',A);   
roiManager("Combine");
roiManager("Add");
roiManager('select',A);   
roiManager("delete");
roiManager("select", 0);
getBoundingRect(x, y, width, height);
makeRectangle(x-15, y-15, width+30, height+30);
roiManager("add");
}

//-----------------------------------------------------------------------------------








