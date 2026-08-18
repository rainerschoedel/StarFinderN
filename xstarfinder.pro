; $Id: xstarfinder.pro, v 1.1 Apr 2000 e.d. $
;
;+
; NAME:
;	XSTARFINDER
;
; PURPOSE:
;	Package for stellar fields analysis.
;
; CATEGORY:
;	Widgets.
;
; CALLING SEQUENCE:
;	XSTARFINDER
;
; KEYWORD PARAMETERS:
;	GROUP:	Group leader, i.e. identifier of the calling widget program
;
;	BLOCK:	Set this keyword to a nonzero value to have the IDL command
;		line blocked when this application is registered
;
;	UVALUE:	User value to be assigned to XStarFinder
;
; COMMON BLOCKS:
;	The common blocks of the procedures FITSTARS (in the file
;	'fitstars.pro') and FIT_KERNEL (in the file 'fit_kernel.pro')
;
; SIDE EFFECTS:
;	Initiates the XMANAGER if it is not already running.
;
; PROCEDURE:
;	Create and register the widget and then exit. The additional data
;	required by the program are stored as a structure of pointers in the
;	user value of a child of the top level base.
;
; MODIFICATION HISTORY:
;	Written by: Emiliano Diolaiti, August-September 1999.
;	Updates:
;	1) Enhanced error handling in event-handler
;	   (Emiliano Diolaiti, April 2000).
;	2) Moved psf_repeat_extract to separate module
;	   Added support for batch jobs and spatially variant PSF
;	   (Rainer Koehler, May 2001)
;-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Format of the structure stored in the usre value of "left_base"
; (commonly called "data" in this module)
; based on my interpretation of the code, RK May 2001
;
; data.image.image:		the image to analyze
;           .image_display_par:
;           .image_hdr: 	header of the FitsFile loaded in .image
;           .background:        the background (loaded or estimated?)
;           .back_display_par:
;           .back_hdr:          header of FitsFile loaded in .background
;           .backbox:
;           .noise_par:
;           .g_noise_par:
;           .plot_par:
;           .noise_std:		image containing noise for each pixel
;           .x_badpix:
;           .y_badpix:
;           .run_par:
;           .x_stars:		x-pos of stars found
;           .y_stars: 		y-pos "    "     "
;           .f_stars: 		flux  "    "     "
;           .sx_stars:		sigma of x
;           .sy_stars:		sigma of y
;           .sf_stars:		sigma of flux
;           .c_stars: 		correlation coefficient of stars found
;           .stars:
;           .stars_display_par:
;           .syn_field:
;           .syn_display_par:
;
;     .psf.psf:
;         .extract_par:
;         .support_par:
;         .smooth_par:
;         .psf_display_par:
;         .psf_hdr:
;         .psf_fwhm:
;         .guide_x:		x-pos of AO Guide star
;         .guide_y:		y-...
;         .x_psf:		x-pos of stars used for PSF-extraction
;         .y_psf:		y-...
;
;     .logfilename:		Name of the logfile to write during analysis
;     .draw:
;     .path:
;     .file:
;     .last_display:
;     .other_display_par:
;     .last_display_par:
;
; end of data structure
;


;;; EVENT PROCEDURES

; LOAD_IMAGE_EV: load FITS format image data from input file and display it.

PRO load_image_ev, data_p, path_p, HDR = hdr_p, $
	               DISPLAY = display, drawid, display_par_p, $
	               LOADED = loaded, FILE = file_p, WIDGET = widg

	on_error, 2
	file = dialog_pickfile(/READ, FILTER = '*.fits*', $
	                       PATH = *path_p, GET_PATH = path)
	loaded = file ne ''
	if  not loaded  then  return
	widget_control, /HOURGLASS
	fits_read, file, data, hdr
	*path_p = path  &  *data_p = data
        if  ptr_valid(file_p)  then  *file_p = file
	if  ptr_valid(hdr_p)  then  *hdr_p = hdr
	if  keyword_set(display) then begin
	   *display_par_p = default_display_opt(data)
	   display_image_ev, drawid, path_p, display_par_p, data_p
	endif
        if  keyword_set(widg) then begin
            basename = file
            p = strpos(basename, "/", /REVERSE_SEARCH)
            if  p gt 0  then  basename = strmid(basename,p+1)
            p = strpos(basename, "\", /REVERSE_SEARCH)
            if  p gt 0  then  basename = strmid(basename,p+1)

            widget_control, widg, SET_VALUE = { tag1: basename }
        endif
	return
end

; DISPLAY_IMAGE_EV: display image data using current options.

PRO display_image_ev, drawid, path_p, display_par_p, data_p, $
                      HDR = hdr_p, FILE = file_p

	;on_error, 2
	no_data = not ptr_valid(data_p)
	if  no_data  then  data_p = ptr_new(/ALLOCATE)
	if  n_elements(*data_p) eq 0  then begin
	   if  not ptr_valid(hdr_p)  then  hdr_p = ptr_new(/ALLOCATE)
	   load_image_ev, data_p, path_p, HDR = hdr_p, FILE = file_p
	endif
	if  size52(*data_p, /N_DIM) ne 2  then  return
	widget_control, /HOURGLASS
	if  n_elements(*display_par_p) eq 0  then $
	   *display_par_p = default_display_opt(*data_p)
	display_image, *data_p, drawid, OPTIONS = *display_par_p
	return
end

; DISPLAY_OPTIONS_EV: modify display options by means of XDisplayOpt.

PRO display_options_ev, drawid, last_data_p, display_par_p, group_leader

	on_error, 2
	if  n_elements(*last_data_p) eq 0  then begin
	   msg = dialog_message('Please select data', /ERROR)
	   return
	endif
	widget_control, /HOURGLASS
	if  size52(*last_data_p, /TYPE) eq 7  then $
	   fits_read, *last_data_p, data  else  data = *last_data_p
	*display_par_p = xdisplayopt(data, drawid, /NODISPLAY, $
				     OPTIONS = *display_par_p, GROUP = group_leader)
	return
end

; SAVE_IMAGE_EV: save image data in FITS-format output file.

PRO save_image_ev, data_p, path_p, HDR = hdr_p

	on_error, 2
	if  n_elements(*data_p) eq 0  then  return
	file = dialog_pickfile(/WRITE, FILTER = '*.fits',  $
						   PATH = *path_p, GET_PATH = path)
	if  file eq ''  then  return
	widget_control, /HOURGLASS
	if  strpos(file, '.fits') lt 0  then  file = file + '.fits'
	*path_p = path
	if  ptr_valid(hdr_p)  then $
	   if  n_elements(*hdr_p) ne 0  then  header = *hdr_p
	writefits, file, *data_p, header
	return
end

; NOISE_STD_EV: compute st. dev. of gaussian noise in the image.

PRO noise_std_ev, data, group_leader

	on_error, 2
	if  n_elements(*data.image.image) eq 0  then begin
	   msg = dialog_message('Please select data', /ERROR)
	   return
	endif
	xnoise, *data.image.image, *data.image.noise_std, WNUM = *data.draw, $
			PATH = *data.path, DEFAULT_PAR = *data.image.noise_par, $
			G_NOISE_PAR = *data.image.g_noise_par, PLOT_PAR = $
			*data.image.plot_par, GROUP = group_leader
	return
end

; REPLACE_BAD_EV: replace bad pixels in the input image.

PRO replace_badpix_ev, data, group_leader

	on_error, 2
	if  n_elements(*data.image.image) eq 0  then begin
	   msg = dialog_message('Please select data', /ERROR)
	   return
	endif
	*data.image.image = xreplace_pix(*data.image.image, $
						*data.image.x_badpix, *data.image.y_badpix, $
						PATH = *data.path, WNUM = *data.draw, $
						DISPLAY_OPT = *data.image.image_display_par, $
						GROUP = group_leader)
	return
end

; PSF_EXTRACT_EV: extract PSF from image.

PRO psf_extract_ev, data, group_leader

	on_error, 2
	if  n_elements(*data.image.image) eq 0  then begin
	   msg = dialog_message('Please select data', /ERROR)
	   return
	endif
	xpsf_extract, *data.image.image, *data.psf.psf, *data.psf.psf_fwhm, $
				  *data.psf.x_psf, *data.psf.y_psf, *data.image.background, $
				  DEFAULT_PAR = *data.psf.extract_par, $
				  IMAGE_DISP = *data.image.image_display_par, $
				  PSF_DISP = *data.psf.psf_display_par, $
          			  GUIDE_X = *data.psf.guide_x, GUIDE_Y = *data.psf.guide_y, $
				  PATH = *data.path, GROUP = group_leader
	if  n_elements(*data.psf.psf_fwhm) ne 0  then begin
	   if  n_elements(*data.psf.extract_par) ne 0  then $
	      n_fwhm = (*data.psf.extract_par).n_fwhm_back  else  n_fwhm = 9
	   *data.image.backbox = round(n_fwhm * *data.psf.psf_fwhm)
	endif
	return
end

; PSF_REPEAT_EV: repeat extraction procedure after 1st analysis.

PRO psf_repeat_ev, data, papa

	on_error, 2
	if  n_elements(*data.image.image) eq 0  then begin
	   msg = dialog_message('Load image first', /ERROR)
	   return
	endif
	if  n_elements(*data.image.stars) eq 0  then begin
	   msg = dialog_message('Analyze the image or load detected stars first', /ERROR)
	   return
	endif
	if  n_elements(*data.psf.extract_par) * $
		n_elements(*data.psf.x_psf) eq 0  then begin
	   msg = dialog_message('Run PSF extraction procedure first', /ERROR)
	   return
	endif
	widget_control, /HOURGLASS

	norm_max = ((*data.psf.extract_par).norm_max eq 1) and 1B
	unweighted = ((*data.psf.extract_par).weigh_med eq 0) and 1B
	*data.psf.psf = psf_repeat_extract( $
				*data.psf.x_psf, *data.psf.y_psf, $
          			*data.image.x_stars, *data.image.y_stars, *data.image.f_stars, $
				*data.image.image, *data.image.background, *data.image.stars, $
				*data.psf.psf, norm_max, unweighted, (*data.psf.extract_par).upper_lev)
	*data.psf.psf_fwhm = fwhm(*data.psf.psf, MAG = 3, /CUBIC)
	msg = dialog_message('Repeated PSF extraction done', /INFO, DIALOG_PARENT=papa)
	return
end

; PSF_SUPPORT_EV: PSF support event.

PRO psf_support_ev, data, group_leader

	on_error, 2
	if  n_elements(*data.psf.psf) eq 0  then begin
	   msg = dialog_message('Please define PSF', /ERROR)
	   return
	endif
	*data.psf.psf = ximage_support(*data.psf.psf, *data.draw, $
                                       *data.psf.psf_display_par, $
                                       DEFAULT_PAR = *data.psf.support_par, $
                                       GROUP = group_leader)
	return
end

; PSF_SMOOTH_EV: PSF halo smooth event.

PRO psf_smooth_ev, data, group_leader

	on_error, 2
	if  n_elements(*data.psf.psf) eq 0  then begin
	   msg = dialog_message('Please define PSF', /ERROR)
	   return
	endif
	*data.psf.psf = xpsf_smooth(*data.psf.psf, *data.draw, $
                                    *data.psf.psf_display_par, $
                                    DEFAULT_PAR = *data.psf.smooth_par, $
                                    GROUP = group_leader)
        return
end

; NORMALIZE_PSF_EV: PSF normalization event.

PRO normalize_psf_ev, data

	on_error, 2
	if  n_elements(*data.psf.psf) eq 0  then begin
	   msg = dialog_message('Please define PSF', /ERROR)
	   return
	endif
	widget_control, /HOURGLASS
	for  rep = 1, 2  do  *data.psf.psf = *data.psf.psf / total(*data.psf.psf)
	return
end

; SELECT_REF_EV: select and save positions of reference stars in a given image.

PRO select_ref_ev, data

	on_error, 2
	if  n_elements(*data.image.image) eq 0  then begin
	   msg = dialog_message('Please select data', /ERROR)
	   return
	endif
	display_image, *data.image.image, *data.draw, $
				   OPTIONS = *data.image.image_display_par
	msg = dialog_message(['Select the reference stars.', '', $
   	   					  'Use the left button of your mouse; ' + $
   	   					  'push the right button to exit.'], /INFO)
   	if  n_elements(*data.psf.psf_fwhm) ne 0  then $
   	   click_box = round(*data.psf.psf_fwhm)  else  click_box = 3
	click_on_max, *data.image.image, /MARK, /SILENT, x, y, $
				  BOXSIZE = click_box, SYMSIZE = click_box
	if  n_elements(x) eq 0 or n_elements(y) eq 0  then  return
	file = dialog_pickfile(/WRITE, FILTER = '*.txt', PATH = *data.path, $
		   GET_PATH = path, TITLE = 'Select file to save reference stars')
	if  file ne '' then begin
	   widget_control, /HOURGLASS
	   if  strpos(file, '.txt') lt 0  then  file = file + '.txt'
	   *data.path = path
	   out = [transpose(x),transpose(y)]
	   openw, lun, file, /GET_LUN
	   printf, lun, out  &  free_lun, lun
	endif
	return
end

; ASTROM_PHOTOM_EV: astrometry and photometry event.

PRO astrom_photom_event, data, group_leader

	on_error, 2
	if  n_elements(*data.image.image) eq 0  then begin
	   msg = dialog_message('Load Image', /ERROR)
	   return
	endif
	if  n_elements(*data.psf.psf) eq 0  then begin
	   msg = dialog_message('Load or estimate PSF', /ERROR)
	   return
	endif
	if  n_elements(*data.psf.psf_fwhm) eq 0  then $
	   *data.psf.psf_fwhm = fwhm(*data.psf.psf, /CUBIC, MAG = 3)
	if  n_elements(*data.image.backbox) eq 0  then begin
	   if  n_elements(*data.psf.extract_par) ne 0  then $
	      n_fwhm = (*data.psf.extract_par).n_fwhm_back  else  n_fwhm = 9
	   *data.image.backbox = round(n_fwhm * *data.psf.psf_fwhm)
	endif
	xstarfinder_run, *data.image.image, *data.psf.psf, *data.psf.psf_fwhm, $
			*data.image.background, BACK_BOX = *data.image.backbox, $
			NOISE_STD = *data.image.noise_std, $
			X_BAD = *data.image.x_badpix, Y_BAD = *data.image.y_badpix, $
			STARS = *data.image.stars, $
			*data.image.x_stars, *data.image.y_stars, *data.image.f_stars, $
			*data.image.sx_stars, *data.image.sy_stars, *data.image.sf_stars, $
			*data.image.c_stars, DEFAULT_PAR = *data.image.run_par, $
          		GUIDE_X = *data.psf.guide_x, GUIDE_Y = *data.psf.guide_y, $
			LOGFILENAME = *data.logfilename, $
			GROUP = group_leader, PATH = *data.path
	if  n_elements(*data.image.f_stars) ne 0  then begin
	   *data.image.syn_field = *data.image.stars
	   if  n_elements(*data.image.background) ne 0  then $
	      *data.image.syn_field = *data.image.syn_field + *data.image.background
	endif
	return
end

; BATCH_EVENT: the user wants to write a batch file

PRO batch_event, data, group_leader

	if  n_elements(*data.image.image) eq 0  then begin
	   msg = dialog_message('Load Image first', /ERROR)
	   return
	endif
	if  n_elements(*data.psf.psf) eq 0  then begin
	   msg = dialog_message('Load or estimate PSF first', /ERROR)
	   return
	endif
	if  n_elements(*data.psf.psf_fwhm) eq 0  then $
	   *data.psf.psf_fwhm = fwhm(*data.psf.psf, /CUBIC, MAG = 3)
	if  n_elements(*data.image.backbox) eq 0  then begin
	   if  n_elements(*data.psf.extract_par) ne 0  then $
	      n_fwhm = (*data.psf.extract_par).n_fwhm_back  else  n_fwhm = 9
	   *data.image.backbox = round(n_fwhm * *data.psf.psf_fwhm)
	endif

        widget_control, /HOURGLASS
        file = dialog_pickfile(/WRITE, FILTER = "*.pro", PATH = *data.path, $
                               TITLE = "Select batch-file")
        if  file ne ""  then begin
            if  strpos(file, '.pro') lt 0  then  file = file + '.pro'
            openw, batchfp, file, /get_lun
            printf, batchfp, ";"
            printf, batchfp, "; ", file
            printf, batchfp, ";"
            printf, batchfp, "; machine-generated batch-file"
            printf, batchfp, "; edit only if you know what you are doing"
            printf, batchfp, ";"

            p = strpos(file, ".pro")
            file = strmid(file,0,p)
            p = strpos(file, "/", /REVERSE_SEARCH)
            if  p lt 0  then  pname = file  else  pname = strmid(file,p+1)
            p = strpos(pname, "\", /REVERSE_SEARCH)
            if  p gt 0  then  pname = strmid(pname,p+1)
            printf, batchfp, 'pro ', pname

            writefits, file + "_img.fits", *data.image.image
            printf, batchfp, 'fits_read, "' + file + '_img.fits", image, img_header'

            writefits, file + "_psf.fits", *data.psf.psf
            printf, batchfp, 'fits_read, "' + file + '_psf.fits", psf, psf_header'

            writefits, file + "_bg.fits",  *data.image.background
            printf, batchfp, 'fits_read, "' + file + '_bg.fits", background, bg_header'

            if  n_elements(*data.image.noise_std) eq 0  then begin
                msg = dialog_message(['You did not load or compute the noise.', $
                                      'Starfinder might run without it, but', $
                                      'that is probably not what you want.'], $
                                     /Information, DIALOG_PARENT = group_leader)
            endif else begin
                writefits, file + "_noise.fits", *data.image.noise_std
                printf, batchfp, 'fits_read, "' + file + '_noise.fits", noise_std, noise_header'
            endelse

            *data.logfilename = file + ".log"

            itcnt = 1
            REPEAT begin
                xstarfinder_run, *data.image.image, *data.psf.psf, *data.psf.psf_fwhm, $
				*data.image.background, BACK_BOX = *data.image.backbox, $
				NOISE_STD = *data.image.noise_std, $
				X_BAD = *data.image.x_badpix, Y_BAD = *data.image.y_badpix, $
				STARS = *data.image.stars, $
				*data.image.x_stars, *data.image.y_stars, *data.image.f_stars, $
				*data.image.sx_stars, *data.image.sy_stars, *data.image.sf_stars, $
				*data.image.c_stars, DEFAULT_PAR = *data.image.run_par, $
          			GUIDE_X = *data.psf.guide_x, GUIDE_Y = *data.psf.guide_y, $
				LOGFILENAME = *data.logfilename, $
				GROUP = group_leader, PATH = *data.path, /BATCH

                ;; now we have all the parameters in the data thingy and have
                ;; to translate it to a batch file...

                par = *data.image.run_par
                str_threshold	= par.dthresh
                threshold       = float(str_sep(strcompress(str_threshold, /REMOVE_ALL), ','))
                rel_thresh      = (par.rel_thresh eq 1) and 1B
                min_correlation = par.cthresh
                correl_mag      = par.csub
                if  par.noise eq 1  then  noise_std = *data.image.noise_std
                if  par.bbox  gt 0  then  back_box  = par.bbox
                deblend = (par.deblend eq 1) and 1B
                niter   = par.niter
                logfilename = *data.logfilename

                if  str_threshold eq ''  then $
                  msg = dialog_message(/ERROR, ['Enter one or more detection thresholds', $
                                                'separated by commas.']) $
                else begin
                    str_itcnt = string(itcnt,FORMAT="(I0)")

                    printf, batchfp
                    printf, batchfp, ';'
                    printf, batchfp, '; ' + str_itcnt + ". Iteration"
                    printf, batchfp, ';'
                    printf, batchfp, 'threshold = [', strjoin(threshold,","), ']'
                    printf, batchfp, 'rel_thresh= ', rel_thresh

                    printf, batchfp, 'back_box  = ', back_box
                    printf, batchfp, 'min_correlation = ', min_correlation
                    printf, batchfp, 'correl_mag = ', correl_mag
                    printf, batchfp, 'deblend = ', deblend
                    printf, batchfp, 'niter   = ', niter
                    printf, batchfp, 'guide_x = "', *data.psf.guide_x, '"'
                    printf, batchfp, 'guide_y = "', *data.psf.guide_y, '"'

                    printf, batchfp, 'starfinder, image, psf, BACKGROUND = background, $'
                    printf, batchfp, '            BACK_BOX = back_box, /SKY_MEDIAN, $'
                    printf, batchfp, '            threshold, REL_THRESHOLD = rel_thresh, /PRE_SMOOTH, $'
                    printf, batchfp, '            NOISE_STD = noise_std, min_correlation, $'
                    printf, batchfp, '            CORREL_MAG = correl_mag, INTERP_TYPE = "I", $'
                    printf, batchfp, '            DEBLEND = deblend, N_ITER = niter, SILENT=0, $'
                    printf, batchfp, '            GUIDE_X = guide_x, GUIDE_Y = guide_y, $'
                    printf, batchfp, '            SV_SIGMA_R = 0.0085, SV_SIGMA_A= 0.0050, $'
                    printf, batchfp, '            x, y, f, sx, sy, sf, c, STARS = stars, $'
                    printf, batchfp, '            LOGFILE = "', logfilename, '"'

                    printf, batchfp, 'nstars = n_elements(f)'
                    printf, batchfp, 'print, strcompress(string(nstars)) + " detected stars."'

                    printf, batchfp, 'out = [transpose(x),  transpose(y),  transpose(f), $'
                    printf, batchfp, '       transpose(sx), transpose(sy), transpose(sf), transpose(c)]'

                    printf, batchfp, 'openw, resfp, "' + file + '_results' + str_itcnt + '.txt", /GET_LUN'
                    printf, batchfp, 'printf,resfp, out'
                    printf, batchfp, 'close, resfp'
                    printf, batchfp, 'writefits, "' + file + '_detstars' + str_itcnt + '.fits", stars'
                    printf, batchfp, 'writefits, "' + file + '_new_back' + str_itcnt + '.fits", background'

                    ;; PSF-reextract

                    norm_max  = ((*data.psf.extract_par).norm_max  eq 1) and 1B
                    unweighted= ((*data.psf.extract_par).weigh_med eq 0) and 1B

                    printf, batchfp
                    printf, batchfp, ';; normalize psf to unit maximum (1) or unit flux (0), default = maximum'
                    printf, batchfp, 'norm_max  = ', norm_max
                    printf, batchfp, ';; use unweighted (1) or weighted (0) median, default = unweighted'
                    printf, batchfp, 'unweighted= ', unweighted
                    printf, batchfp, 'saturation= ', (*data.psf.extract_par).upper_lev

                    printf, batchfp, 'x_psf = [' + strjoin(*data.psf.x_psf,",") + ' ]'
                    printf, batchfp, 'y_psf = [' + strjoin(*data.psf.y_psf,",") + ' ]'
                    printf, batchfp, 'psf = psf_repeat_extract( x_psf, y_psf, x, y, f, image, background, $'
                    printf, batchfp, '                          stars, psf, norm_max, unweighted, saturation)'
                    printf, batchfp, 'writefits, "' + file + '_psf' + str_itcnt + '.fits", psf'

                    itcnt = itcnt + 1

                endelse ; if no thresholds...

                msg = dialog_message('Do you want to add more find stars/re-extract PSF iterations?', $
                                     /Question, DIALOG_PARENT = group_leader )

            endrep UNTIL msg eq "No"
            printf, batchfp, 'end'
            close, batchfp

            msg = dialog_message('Batch job created', /Information, DIALOG_PARENT = group_leader)

        endif ; if file ne ''
        return
end


; SAVE_LIST_EV: save list of detected stars.

PRO save_list_ev, data

	if  n_elements(*data.image.f_stars) eq 0  then begin
	   msg = dialog_message('Analyze the image', /ERROR)
	   return
	endif
	file = dialog_pickfile(/WRITE, FILTER = '*.txt', PATH = *data.path, $
		   GET_PATH = path, TITLE = 'Select file to save list of stars')
	if  file ne '' then begin
	   widget_control, /HOURGLASS
	   if  strpos(file, '.txt') lt 0  then  file = file + '.txt'
	   *data.path = path
	   out = [transpose(*data.image.x_stars), $
	          transpose(*data.image.y_stars), $
	          transpose(*data.image.f_stars), $
	          transpose(*data.image.sx_stars), $
	          transpose(*data.image.sy_stars), $
	          transpose(*data.image.sf_stars), $
	          transpose(*data.image.c_stars)]
	   openw, lun, file, /GET_LUN
           printf, FORMAT = '("#", 7(A13))', lun, "x position ", "y position ", "flux ", $
             "sigma x ", "sigma y ", "sigma flux ", "correlation "
	   printf, FORMAT = '(7(G13.6))', lun, out
           free_lun, lun
	endif
	return
end

; SAVE_LIST_DS9_EV: save detected stars in ds9-region

PRO save_list_ds9_ev, data

	if  n_elements(*data.image.f_stars) eq 0  then begin
	   msg = dialog_message('Analyze the image', /ERROR)
	   return
	endif
	file = dialog_pickfile(/WRITE, FILTER = '*.ds9', PATH = *data.path, $
		   GET_PATH = path, TITLE = 'Select region-file to save list of stars')
	if  file ne '' then begin
	   widget_control, /HOURGLASS
	   if  strpos(file, '.ds9') lt 0  then  file = file + '.ds9'
	   *data.path = path
	   out = [transpose(*data.image.x_stars)+1, $
	          transpose(*data.image.y_stars)+1 ]
	   openw, lun, file, /GET_LUN
           printf, lun, "# Region file format: DS9 version 3.0"
           printf, lun, 'global color=green font="helvetica 10 normal" edit=1 move=0 delete=1 include=1 fixed=0'
	   printf, FORMAT = '("image;circle(", G, ",", G, ",5)")', lun, out
           free_lun, lun
	endif
	return
end


; INIT_DATA: initialize pointers to image or PSF data.

PRO init_data, data, field

	on_error, 2
	widget_control, /HOURGLASS
	case  field  of
	   'image': begin
	      ptr_free, $
	         data.image.background, data.image.back_display_par, $
	         data.image.back_hdr, data.image.backbox, data.image.noise_std, $
	         data.image.x_badpix, data.image.y_badpix, data.image.stars, $
	         data.image.x_stars, data.image.y_stars, data.image.f_stars, $
	         data.image.sx_stars, data.image.sy_stars, data.image.sf_stars, $
	         data.image.c_stars, data.image.stars_display_par, $
	         data.image.syn_field, data.image.syn_display_par
	      data.image.background = ptr_new(/ALLOCATE)
	      data.image.back_display_par = ptr_new(/ALLOCATE)
	      data.image.back_hdr = ptr_new(/ALLOCATE)
	      data.image.backbox = ptr_new(/ALLOCATE)
	      data.image.noise_std = ptr_new(/ALLOCATE)
	      data.image.x_badpix = ptr_new(/ALLOCATE)
	      data.image.y_badpix = ptr_new(/ALLOCATE)
	      data.image.x_stars = ptr_new(/ALLOCATE)
	      data.image.y_stars = ptr_new(/ALLOCATE)
	      data.image.f_stars = ptr_new(/ALLOCATE)
	      data.image.sx_stars = ptr_new(/ALLOCATE)
	      data.image.sy_stars = ptr_new(/ALLOCATE)
	      data.image.sf_stars = ptr_new(/ALLOCATE)
	      data.image.c_stars = ptr_new(/ALLOCATE)
	      data.image.stars = ptr_new(/ALLOCATE)
	      data.image.stars_display_par = ptr_new(/ALLOCATE)
	      data.image.syn_field = ptr_new(/ALLOCATE)
	      data.image.syn_display_par = ptr_new(/ALLOCATE)
	      end
	   'psf': begin
	      ptr_free, data.psf.psf_fwhm, data.psf.x_psf, data.psf.y_psf
	      data.psf.psf_fwhm = ptr_new(/ALLOCATE)
	      data.psf.x_psf = ptr_new(/ALLOCATE)
	      data.psf.y_psf = ptr_new(/ALLOCATE)
	      end
	   endcase
	return
end

; CHECK_PTR: check undefined heap variables in data structure.

PRO check_ptr, data, action

	on_error, 2
	widget_control, /HOURGLASS
	case  action  of
	   'in': begin
	      if  not ptr_valid(data.logfilename)  then  data.logfilename = ptr_new("")
	      if  not ptr_valid(data.draw)  then  data.draw = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.path)  then  data.path = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.file)  then  data.file = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.last_display)  then  data.last_display = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.last_display_par)  then  data.last_display_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.other_display_par)  then  data.other_display_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.image)  then  data.image.image = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.image_display_par)  then  data.image.image_display_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.image_hdr)  then  data.image.image_hdr = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.background)  then  data.image.background = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.back_display_par)  then  data.image.back_display_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.back_hdr)  then  data.image.back_hdr = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.backbox)  then  data.image.backbox = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.noise_par)  then  data.image.noise_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.g_noise_par)  then  data.image.g_noise_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.plot_par)  then  data.image.plot_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.noise_std)  then  data.image.noise_std = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.x_badpix)  then  data.image.x_badpix = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.y_badpix)  then  data.image.y_badpix = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.run_par)  then  data.image.run_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.x_stars)  then  data.image.x_stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.y_stars)  then  data.image.y_stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.f_stars)  then  data.image.f_stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.sx_stars)  then  data.image.sx_stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.sy_stars)  then  data.image.sy_stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.sf_stars)  then  data.image.sf_stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.c_stars)  then  data.image.c_stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.stars)  then  data.image.stars = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.stars_display_par)  then  data.image.stars_display_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.syn_field)  then  data.image.syn_field = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.image.syn_display_par)  then  data.image.syn_display_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.psf)  then  data.psf.psf = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.extract_par)  then  data.psf.extract_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.support_par)  then  data.psf.support_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.smooth_par)  then  data.psf.smooth_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.psf_display_par)  then  data.psf.psf_display_par = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.psf_hdr)  then  data.psf.psf_hdr = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.psf_fwhm)  then  data.psf.psf_fwhm = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.guide_x)  then  data.psf.guide_x = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.guide_y)  then  data.psf.guide_y = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.x_psf)  then  data.psf.x_psf = ptr_new(/ALLOCATE)
	      if  not ptr_valid(data.psf.y_psf)  then  data.psf.y_psf = ptr_new(/ALLOCATE)
	      end
	   'out': begin
	      if  n_elements(*data.logfilename) eq 0  then  data.logfilename = ptr_new("")
	      if  n_elements(*data.draw) eq 0  then  data.draw = ptr_new()
	      if  n_elements(*data.path) eq 0  then  data.path = ptr_new()
	      if  n_elements(*data.file) eq 0  then  data.file = ptr_new()
	      if  n_elements(*data.last_display) eq 0  then  data.last_display = ptr_new()
	      if  n_elements(*data.last_display_par) eq 0  then  data.last_display_par = ptr_new()
	      if  n_elements(*data.other_display_par) eq 0  then  data.other_display_par = ptr_new()
	      if  n_elements(*data.image.image) eq 0  then  data.image.image = ptr_new()
	      if  n_elements(*data.image.image_display_par) eq 0  then  data.image.image_display_par = ptr_new()
	      if  n_elements(*data.image.image_hdr) eq 0  then  data.image.image_hdr = ptr_new()
	      if  n_elements(*data.image.background) eq 0  then  data.image.background = ptr_new()
	      if  n_elements(*data.image.back_display_par) eq 0  then  data.image.back_display_par = ptr_new()
	      if  n_elements(*data.image.back_hdr) eq 0  then  data.image.back_hdr = ptr_new()
	      if  n_elements(*data.image.backbox) eq 0  then  data.image.backbox = ptr_new()
	      if  n_elements(*data.image.noise_par) eq 0  then  data.image.noise_par = ptr_new()
	      if  n_elements(*data.image.g_noise_par) eq 0  then  data.image.g_noise_par = ptr_new()
	      if  n_elements(*data.image.plot_par) eq 0  then  data.image.plot_par = ptr_new()
	      if  n_elements(*data.image.noise_std) eq 0  then  data.image.noise_std = ptr_new()
	      if  n_elements(*data.image.x_badpix) eq 0  then  data.image.x_badpix = ptr_new()
	      if  n_elements(*data.image.y_badpix) eq 0  then  data.image.y_badpix = ptr_new()
	      if  n_elements(*data.image.run_par) eq 0  then  data.image.run_par = ptr_new()
	      if  n_elements(*data.image.x_stars) eq 0  then  data.image.x_stars = ptr_new()
	      if  n_elements(*data.image.y_stars) eq 0  then  data.image.y_stars = ptr_new()
	      if  n_elements(*data.image.f_stars) eq 0  then  data.image.f_stars = ptr_new()
	      if  n_elements(*data.image.sx_stars) eq 0  then  data.image.sx_stars = ptr_new()
	      if  n_elements(*data.image.sy_stars) eq 0  then  data.image.sy_stars = ptr_new()
	      if  n_elements(*data.image.sf_stars) eq 0  then  data.image.sf_stars = ptr_new()
	      if  n_elements(*data.image.c_stars) eq 0  then  data.image.c_stars = ptr_new()
	      if  n_elements(*data.image.stars) eq 0  then  data.image.stars = ptr_new()
	      if  n_elements(*data.image.stars_display_par) eq 0  then  data.image.stars_display_par = ptr_new()
	      if  n_elements(*data.image.syn_field) eq 0  then  data.image.syn_field = ptr_new()
	      if  n_elements(*data.image.syn_display_par) eq 0  then  data.image.syn_display_par = ptr_new()
	      if  n_elements(*data.psf.psf) eq 0  then  data.psf.psf = ptr_new()
	      if  n_elements(*data.psf.extract_par) eq 0  then  data.psf.extract_par = ptr_new()
	      if  n_elements(*data.psf.support_par) eq 0  then  data.psf.support_par = ptr_new()
	      if  n_elements(*data.psf.smooth_par) eq 0  then  data.psf.smooth_par = ptr_new()
	      if  n_elements(*data.psf.psf_display_par) eq 0  then  data.psf.psf_display_par = ptr_new()
	      if  n_elements(*data.psf.psf_hdr) eq 0  then  data.psf.psf_hdr = ptr_new()
	      if  n_elements(*data.psf.psf_fwhm) eq 0  then  data.psf.psf_fwhm = ptr_new()
	      if  n_elements(*data.psf.guide_x) eq 0  then  data.psf.guide_x = ptr_new()
	      if  n_elements(*data.psf.guide_y) eq 0  then  data.psf.guide_y = ptr_new()
	      if  n_elements(*data.psf.x_psf) eq 0  then  data.psf.x_psf = ptr_new()
	      if  n_elements(*data.psf.y_psf) eq 0  then  data.psf.y_psf = ptr_new()
	      end
	   endcase
	return
end

; SESSION_EV: save or restore XStarFinder session.

PRO session_ev, data, action

	on_error, 2
	case  action  of
	   'save': begin
	      file = dialog_pickfile(/WRITE, FILTER = '*.sav', $
	      						 PATH = *data.path, GET_PATH = path)
	      if  file ne '' then begin
	         widget_control, /HOURGLASS
	         if  strpos(file, '.sav') lt 0  then  file = file + '.sav'
	         *data.path = path
	         check_ptr, data, 'out'
	         save, FILENAME = file, data
	         check_ptr, data, 'in'
	      endif
	      end
	   'restore': begin
	      file = dialog_pickfile(/READ, FILTER = '*.sav', $
	      						 PATH = *data.path, GET_PATH = path)
	      if  file ne '' then begin
	         widget_control, /HOURGLASS
	         restore, file
	         check_ptr, data, 'in'
	         *data.path = path
	      endif
	      end
	endcase
	return
end

; XSTARFINDER_HELP_EV: display help file.

PRO xstarfinder_help_ev, name, group

	on_error, 2
	file = '_help.txt'  &  title = ' help'
	case strlowcase(name) of
	   'xstarfinder': begin
	      file = 'xstarfinder' + file
	      title = 'XStarFinder' + title
	      end
	   'image': begin
	      file = 'image' + file
	      title = 'Image' + title
	      end
	   'psf': begin
	      file = 'psf' + file
	      title = 'PSF' + title
	      end
	   'display': begin
	      file = 'display' + file
	      title = 'Display' + title
	      end
	endcase
	xdispfile, file_name('starfinder', file), TITLE = title, GROUP = group
	return
end

; XSTARFINDER_EVENT: XStarFinder event handler.

PRO xstarfinder_event, event

	catch, error
	if  error ne 0  then begin
            help, calls=traceback
	   msg = dialog_message(/ERROR, [ "Error in xstarfinder_event: ", !err_string, traceback ])
	   child = widget_info(event.top, /CHILD)
	   widget_control, child, SET_UVALUE = data, /NO_COPY
	   return
	endif
	child = widget_info(event.top, /CHILD)
	widget_control, child, GET_UVALUE = data, /NO_COPY

        info = widget_info(child, /CHILD)

	quit_confirm = 0B
	case event.value of

	   'Image.Load....Image': begin
	      load_image_ev, data.image.image, data.path, $
	      				 HDR = data.image.image_hdr, /DISPLAY, $
	      				 *data.draw, data.image.image_display_par, $
	      				 LOADED = loaded, WIDGET = info
	      if  loaded  then begin
	         init_data, data, 'image'
	         data.last_display = data.image.image
	         data.last_display_par = data.image.image_display_par
	      endif
	      end
	   'Image.Load....Background': begin
	      load_image_ev, data.image.background, data.path, $
	      				 HDR = data.image.back_hdr, /DISPLAY, $
	      				 *data.draw, data.image.back_display_par
	      data.last_display = data.image.background
	      data.last_display_par = data.image.back_display_par
	      end
           'Image.Load....Detected stars': begin
               load_image_ev, data.image.stars, data.path, /DISPLAY, $
					*data.draw, data.image.stars_display_par
               data.last_display = data.image.stars
               data.last_display_par = data.image.stars_display_par
	      end
           'Image.Load....List of stars': begin
               file = dialog_pickfile(/READ, FILTER = '*.txt', PATH = *data.path, $
                                      GET_PATH = path, TITLE = 'Select file containing list of stars')
               if  file ne '' then begin
                   widget_control, /HOURGLASS
                   *data.path = path
                   load_list, file, *data.image.x_stars, *data.image.y_stars, *data.image.f_stars, $
                                    *data.image.sx_stars,*data.image.sy_stars,*data.image.sf_stars, $
                                    *data.image.c_stars
               endif
           end
	   'Image.Noise.Load': load_image_ev, data.image.noise_std, data.path
	   'Image.Noise.Compute': noise_std_ev, data, event.top
	   'Image.Bad Pixels': replace_badpix_ev, data, event.top
	   'Image.Reference sources': select_ref_ev, data
	   'Image.Help': xstarfinder_help_ev, 'image', event.top
	   'Image.Save.Image': $
	      save_image_ev, data.image.image, data.path, $
	   					 HDR = data.image.image_hdr
	   'Image.Save.Background': $
	      save_image_ev, data.image.background, data.path, $
	      				 HDR = data.image.back_hdr
	   'Image.Save.Detected stars': $
	      save_image_ev, data.image.stars, data.path
	   'Image.Save.Synthetic field': $
	      save_image_ev, data.image.syn_field, data.path
	   'Image.Save.Residuals': begin
               resi = ptr_new(*data.image.image - *data.image.syn_field)
               save_image_ev, resi, data.path
               ptr_free, resi
	       end
	   'Image.Save.List of stars': save_list_ev, data
	   'Image.Save.- as DS9-region': save_list_ds9_ev, data

	   'PSF.Load PSF': begin
	      load_image_ev, data.psf.psf, data.path, $
	      				 HDR = data.psf.psf_hdr, /DISPLAY, $
	      				 *data.draw, data.psf.psf_display_par, $
	      				 LOADED = loaded
	      if  loaded  then begin
	         init_data, data, 'psf'
	         data.last_display = data.psf.psf
	         data.last_display_par = data.psf.psf_display_par
	      endif
	      end
           'PSF.Load PSF-stars': begin
               file = dialog_pickfile(/READ, FILTER = '*.txt', PATH = *data.path, $
                                      GET_PATH = path, TITLE = 'Select file containing list of psf stars')
               if  file ne '' then begin
                   widget_control, /HOURGLASS
                   *data.path = path
                   in = transpose( long( read_float_data(file,2)))
                   *data.psf.x_psf = in(*,0)
                   *data.psf.y_psf = in(*,1)
               endif
           end
	   'PSF.Extract from image': psf_extract_ev, data, event.top
	   'PSF.Repeat extraction': psf_repeat_ev, data, event.top
	   'PSF.Support':	 psf_support_ev, data, event.top
	   'PSF.Halo smoothing': psf_smooth_ev, data, event.top
	   'PSF.Normalize': normalize_psf_ev, data
	   'PSF.Help': xstarfinder_help_ev, 'psf', event.top
	   'PSF.Save PSF': $
	       save_image_ev, data.psf.psf, data.path, HDR = data.psf.psf_hdr
           'PSF.Save PSF-stars': begin
               file = dialog_pickfile(/WRITE, FILTER = '*.txt', $
                                      PATH = *data.path, GET_PATH = path)
               if  file ne ''  then begin
                   widget_control, /HOURGLASS
                   if  strpos(file, '.txt') lt 0  then  file = file + '.txt'
                   *data.path = path
                   out = [transpose(*data.psf.x_psf), transpose(*data.psf.y_psf)]
                   openw, lun, file, /GET_LUN
                   printf, lun, "# position x  position y"
                   printf, lun, out  &  free_lun, lun
               endif
           end

	   'Astrometry and Photometry': astrom_photom_event, data, event.top

           'Create Batch Job': batch_event, data, event.top

	   'Compare Lists': $
	      xcompare_lists, *data.draw, PATH = *data.path, GROUP = event.top

	   'Display.Select data.Image': begin
	      display_image_ev, *data.draw, data.path, $
	      					data.image.image_display_par, $
	      					data.image.image, HDR = data.image.image_hdr
	      data.last_display = data.image.image
	      data.last_display_par = data.image.image_display_par
	      end
	   'Display.Select data.PSF': begin
	      display_image_ev, *data.draw, data.path, $
	      					data.psf.psf_display_par, $
	      					data.psf.psf, HDR = data.psf.psf_hdr
	      data.last_display = data.psf.psf
	      data.last_display_par = data.psf.psf_display_par
	      end
	   'Display.Select data.Background': begin
	      display_image_ev, *data.draw, data.path, $
	      					data.image.back_display_par, $
	      					data.image.background, HDR = data.image.back_hdr
	      data.last_display = data.image.background
	      data.last_display_par = data.image.back_display_par
	      end
	   'Display.Select data.Detected stars': begin
	      display_image_ev, *data.draw, data.path, $
	      					data.image.stars_display_par, $
	      					data.image.stars
	      data.last_display = data.image.stars
	      data.last_display_par = data.image.stars_display_par
	      end
	   'Display.Select data.Synthetic field': begin
	      display_image_ev, *data.draw, data.path, $
	      					data.image.syn_display_par, $
	      					data.image.syn_field
	      data.last_display = data.image.syn_field
	      data.last_display_par = data.image.syn_display_par
	      end
	   'Display.Select data.Residuals': begin
               print, "display resis"
               if  not ptr_valid(data.image.syn_field) or n_elements(*data.image.syn_field) eq 0  then begin
                   print, "synthesizing field"
                   *data.image.syn_field = *data.image.stars + *data.image.background
               endif
               resi = ptr_new(*data.image.image - *data.image.syn_field)
               display_image_ev, *data.draw, data.path, $
	      					data.image.back_display_par, resi
               ptr_free, resi
	       end
	   'Display.Select data.Other...': begin
	      ptr_free, data.other_display_par
	      data.other_display_par = ptr_new(/ALLOCATE)
	      display_image_ev, *data.draw, data.path, $
	                        data.other_display_par, FILE = data.file
	      data.last_display = data.file
	      data.last_display_par = data.other_display_par
	      end
	   'Display.Options': $
	      display_options_ev, *data.draw, data.last_display, $
	      			  data.last_display_par, event.top
	   'Display.Help': xstarfinder_help_ev, 'display', event.top

	   'Session.Save': session_ev, data, 'save'
	   'Session.Restore': session_ev, data, 'restore'

	   'Help': xstarfinder_help_ev, 'xstarfinder', event.top

	   'Quit': begin
	      msg = dialog_message(/QUESTION, 'Really quit XStarFinder?',DIALOG_PARENT=event.top)
	      quit_confirm = strlowcase(msg) eq 'yes'
	      if  quit_confirm  then begin
	         xstarfinder_del, data		; de-allocates heap variables
	         widget_control, event.top, /DESTROY
	      endif
	      end

	   else:

	endcase
	if  event.value ne 'Quit' or $
		event.value eq 'Quit' and not quit_confirm  then $
	   widget_control, child, SET_UVALUE = data, /NO_COPY
	return
end



;;; WIDGET DEFINITION PROCEDURES/FUNCTIONS

; XSTARFINDER_PROCESSING_MENU: define menu 1.

FUNCTION xstarfinder_processing_menu

	return, ['1\Image', $
			'1\Load...', $
				'0\Image', $
		                '0\Background', $
		                '0\Detected stars', $
		                '2\List of stars', $
			'1\Noise', $
				'0\Compute', '2\Load', $
			'0\Bad Pixels', $
			'0\Reference sources', $
			'1\Save', $
				'0\Image', $
				'0\Background', $
				'0\Detected stars', $
				'0\Synthetic field', $
				'0\Residuals', $
				'0\List of stars', $
		                '2\- as DS9-region', $
			'2\Help', $   ; end of Image sub-menu
		 '1\PSF', $
			 '0\Load PSF', $
			 '0\Load PSF-stars', $
			 '0\Extract from image', $
			 '0\Repeat extraction', $
			 '0\Support', $
	                 '0\Halo smoothing', $
			 '0\Normalize', $
			 '0\Save PSF', $
			 '0\Save PSF-stars', $
			 '2\Help',	$   ; end of PSF sub-menu
		 '0\Astrometry and Photometry', $   ; Astrometry - Photometry button
		 '0\Create Batch Job', $   ; Yet another button
		 '0\Compare Lists']   ; Compare Lists button
end

; XSTARFINDER_UTILITIES_MENU: define menu 2.

FUNCTION xstarfinder_utilities_menu

	return, ['1\Display', $
			 '1\Select data', '0\Image', '0\PSF', '0\Background', $
			 '0\Detected stars', '0\Synthetic field', '0\Residuals', '2\Other...', $
			 '0\Options', '2\Help', $
			 '1\Session', '0\Save', '2\Restore', '0\Help', '0\Quit']
end

; XSTARFINDER_DEF: define structure of pointers to the data
; required by the program.

FUNCTION xstarfinder_def

	return, $
	{ image: $		; image data
		{image: ptr_new(/ALLOCATE), $
		 image_display_par: ptr_new(/ALLOCATE), $
		 image_hdr: ptr_new(/ALLOCATE), $
		 background: ptr_new(/ALLOCATE), $
		 back_display_par: ptr_new(/ALLOCATE), $
		 back_hdr: ptr_new(/ALLOCATE), $
		 backbox: ptr_new(/ALLOCATE), $
		 noise_par: ptr_new(/ALLOCATE), $
		 g_noise_par: ptr_new(/ALLOCATE), $
		 plot_par: ptr_new(/ALLOCATE), $
		 noise_std: ptr_new(/ALLOCATE), $
		 x_badpix: ptr_new(/ALLOCATE), y_badpix: ptr_new(/ALLOCATE), $
		 run_par: ptr_new(/ALLOCATE), $
		 x_stars: ptr_new(/ALLOCATE), $
		 y_stars: ptr_new(/ALLOCATE), $
		 f_stars: ptr_new(/ALLOCATE), $
		 sx_stars: ptr_new(/ALLOCATE), $
		 sy_stars: ptr_new(/ALLOCATE), $
		 sf_stars: ptr_new(/ALLOCATE), $
		 c_stars: ptr_new(/ALLOCATE), $
		 stars: ptr_new(/ALLOCATE), stars_display_par: ptr_new(/ALLOCATE), $
		 syn_field: ptr_new(/ALLOCATE), syn_display_par: ptr_new(/ALLOCATE)}, $
	  psf: $		; PSF data
	  	{psf: ptr_new(/ALLOCATE), $
		 extract_par: ptr_new(/ALLOCATE), $
		 support_par: ptr_new(/ALLOCATE), $
		 smooth_par: ptr_new(/ALLOCATE), $
	  	 psf_display_par: ptr_new(/ALLOCATE), $
	  	 psf_hdr: ptr_new(/ALLOCATE), $
	  	 psf_fwhm: ptr_new(/ALLOCATE), $
                 guide_x:  ptr_new(/ALLOCATE), guide_y: ptr_new(/ALLOCATE), $
                 sv_sigma_r: ptr_new(/ALLOCATE), sv_sigma_a: ptr_new(/ALLOCATE), $
	  	 x_psf: ptr_new(/ALLOCATE), y_psf: ptr_new(/ALLOCATE)}, $
          logfilename: ptr_new(""),	$
	  draw: ptr_new(/ALLOCATE),		$
	  path: ptr_new(/ALLOCATE),		$
	  file: ptr_new(/ALLOCATE),		$
	  last_display: ptr_new(/ALLOCATE),	 $
	  other_display_par: ptr_new(/ALLOCATE), $
	  last_display_par: ptr_new(/ALLOCATE) }
end

; XSTARFINDER_DEL: delete heap variables.

PRO xstarfinder_del, data

	on_error, 2
	; de-allocate memory pointed by data structure fields
	ptr_free, data.image.image, data.image.image_display_par, $
		  data.image.image_hdr, data.image.background, $
		  data.image.back_display_par, data.image.back_hdr, $
		  data.image.backbox, data.image.noise_par, $
		  data.image.g_noise_par, data.image.plot_par, $
		  data.image.noise_std, data.image.x_badpix, data.image.y_badpix, $
		  data.image.run_par, data.image.x_stars, data.image.y_stars, $
		  data.image.f_stars, data.image.sx_stars, data.image.sy_stars, $
		  data.image.sf_stars, data.image.c_stars, data.image.stars, $
		  data.image.stars_display_par, data.image.syn_field, $
		  data.image.syn_display_par, $
		  data.psf.psf, data.psf.extract_par, data.psf.support_par, $
		  data.psf.smooth_par, data.psf.psf_display_par, $
		  data.psf.psf_hdr, data.psf.psf_fwhm, $
		  data.psf.guide_x, data.psf.guide_y, $
		  data.psf.x_psf, data.psf.y_psf, $
		  data.logfilename, data.draw, data.path, data.file, data.last_display, $
		  data.other_display_par, data.last_display_par
	; de-allocate any inaccessible heap variables
	heap_gc
	return
end

; XSTARFINDER: XStarFinder widget definition module.

PRO xstarfinder, GROUP = group, BLOCK = block, UVALUE = uvalue
        
        device, decomposed = 0
        print, 'device set to pseudo-colors'
	on_error, 2
	; define top level base, partitioned into two parts: left and right
	if  n_elements(uvalue) eq 0  then  uvalue = 0B
	s = round(0.9 * min(get_screen_size()))
	base = widget_base(TITLE = 'XStarFinder TNG', COLUMN = 2, UVALUE  = uvalue)
	left_base = widget_base(base, ROW = 3)
	right_base = widget_base(base)
        ; define information part
        info = cw_form(left_base, $
                       ['0, BASE,Frame,Row', '2, Text, -None-, Left, LABEL_TOP=Image:, WIDTH=24'], IDS=ids)

	; define commands (in left part of base)
	menu = xstarfinder_processing_menu()
	processing = cw_pdmenu(left_base, menu, /COLUMN, /RETURN_FULL_NAME)
	menu = xstarfinder_utilities_menu()
	util = cw_pdmenu(left_base, menu, /COLUMN, /RETURN_FULL_NAME)
	; define draw window (in right part of base)
	draw = widget_draw(right_base, SCR_XSIZE = s, SCR_YSIZE = s, $
					   /ALIGN_CENTER, RETAIN = 2)
	; realize widgets
	widget_control, base, /REALIZE
	widget_control, draw, GET_VALUE = wnum
	; allocate memory for global data and store it in user value
	; of the left base
	data = xstarfinder_def()  &  *data.draw = wnum
        *data.psf.guide_x = ""  & *data.psf.guide_y = ""
	widget_control, left_base, SET_UVALUE = data, /NO_COPY
	; register with XManager
	xmanager, 'xstarfinder', base, EVENT_HANDLER = 'xstarfinder_event', $
			  GROUP_LEADER = group, NO_BLOCK = not keyword_set(block) and 1B
	return
end
