
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
	j=i+1;
	
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
		Junction=Imdir+jctn[i]+ListImJcn[0];	
		run("Image Sequence...", "open=[Junction] sort");
		run("Set Scale...", "distance=1 known="+xypix+" pixel=1 unit=um");
		extractChannel_RGB(chan_presyn,chan_postsyn);
		}


	selectWindow("stack_presyn");
	rename(presyn);
	selectWindow("stack_postsyn");
	rename(postsyn);
	

//----------------------------------------------------------------------

selectWindow(postsyn);
	run("Z Project...", "projection=[Max Intensity]");
	selectWindow("MAX_"+postsyn);
	setAutoThreshold("Yen dark");
	setOption("BlackBackground", false);
	run("Convert to Mask");
	run("Median...", "radius=2");

	
	run("Analyze Particles...", "size=20-1000 add");
	selectWindow(postsyn);
	roiManager("Select", 0);
	run("Crop");
	rename(postsyn);
	run("Select None");
	roiManager("reset");


	selectWindow("MAX_"+postsyn);
	run("Select None");
	run("Analyze Particles...", "size=20-1000  add");
	selectWindow(presyn);
	roiManager("select", 0);
	run("Crop");
	rename(presyn);
	run("Select None");
	roiManager("reset");

	selectWindow("MAX_"+postsyn);
	run("Select None");
	run("Analyze Particles...", "size=20-1000  add");
	
	selectWindow("stackMax");
	run("Z Project...", "projection=[Max Intensity]");
	selectWindow("MAX_stackMax");
	roiManager("select", 0);
	run("Crop");
	saveAs("Tiff", pathsave + "Maxproj_crop_jonction"+j+".tif");
	close();
	
	
	
	// Positionning in the middle of bungarotoxin stack for thresholding
	selectWindow(postsyn);
	Midslice=nSlices/2+1;
	setSlice(Midslice);

	//Otsu Thresholding
	setAutoThreshold("Otsu");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Otsu background=Dark");
	run("Invert","stack");
	run("Dilate","stack");
	//Analysis of detected surfaces
	run("Analyze Particles...", "size=20-Infinity pixel show=[Bare Outlines] display exclude stack");
	//Saving the detected surfaces contour
	selectWindow("Drawing of "+postsyn);
	saveAs("Tiff", pathsave + "Drawing_" + postsyn + "_junction" +j+".tif");
	selectWindow("Drawing_"+postsyn+"_junction"+j+".tif");
	close();
	
	// Summing all the surface area of detected surfaces = Volume of bungatoxin staining
		n=getValue("results.count");
		a=0;
		post=0;
		for(k=0; k<n; k=k+1)
 			{
			post=getResult("Area",k) + a;
			a=post;
			}
	selectWindow("Results");
	saveAs("Results", pathsave + "Results_Volume_" + postsyn + "_junction" + j + ".csv");
	run("Close");
	
	
	// Positionning in the middle of NF stack for thresholding
	selectWindow(presyn);
	setSlice(Midslice);

	//Otsu Thresholding
	setAutoThreshold("Otsu");
	setOption("BlackBackground", false);
	run("Convert to Mask", "method=Otsu background=Dark");
	run("Invert","stack");
	run("Dilate","stack");
	//Analysis of detected surfaces
	run("Analyze Particles...", "size=20-Infinity pixel show=[Bare Outlines] display exclude stack");
	//Saving the detected surfaces contour
	selectWindow("Drawing of "+presyn);
	saveAs("Tiff", pathsave + "Drawing_"+presyn+"_junction" +j+".tif");
	selectWindow("Drawing_"+presyn+"_junction"+j+".tif");
	close();
	
	// Summing all the surface area of detected surfaces = Volume of NF staining
	selectWindow("Results");
		n=getValue("results.count");
		a=0;
		pre=0;
		for(p=0; p<n; p=p+1)
 			{
			pre=getResult("Area",p) + a;
			a=pre;
			}

	//Calculation of NF accumulation by making the ratio between NF volume and Bungarotoxin volume
	Ratio=pre/post*100;
	saveAs("Results", pathsave + "Results_Volume_"+presyn+"_junction" + j + ".xls");
	run("Close");
	selectWindow(postsyn);
	run("Close");
	selectWindow(presyn);
	run("Close");

	//Calculation of actual volume in Âµm^3 (Slices are acquired every 0.5Âµm)
	prev=pre*zstep;
	postv=post*zstep;
	
	//Results Display 
	print("Junction ",j," : Presynaptic Volume (um^3) : ",prev, "Postsynaptic Volume (um^3) : ", postv,"Ratio Accu : ",Ratio);
	run("Close All");

}
	//Saving the final results of volumes and accumulation. 
	selectWindow("Log");
	saveAs("Text",pathsave+"Log_analysis.csv");




//FUNCTIONS 

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


//-----------------------------------------------------------------------------------








