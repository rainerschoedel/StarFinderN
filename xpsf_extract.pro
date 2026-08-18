 $Id: xpsf_extract, v 1.1 Apr 2000 e.d. $
;
;+
; NAME:
;	XPSF_EXTRACT
;
; PURPOSE:
;	Widget interface for the PSF_EXTRACT procedure.
;	Given a stellar field image, extract an estimate of the PSF
;	by combination of a set of stars selected by the user.
;
; CATEGORY:
;	Widgets. Signal processing.
;
; CALLING SEQUENCE:
;	XPSF_EXTRACT, Image, Psf, Psf_fwhm, Background
;
; INPUTS:
;	Image:	Stellar field
;
; KEYWORD PARAMETERS:
;	IMAGE_DISPLAY_OPT:	 Structure of current image display options;
;		the structure must be defined as in DEFAULT_DISPLAY_OPT.
;
;	PSF_DISPLAY_OPT:	Structure of current PSF display options;
;		the structure must be defined as in DEFAULT_DISPLAY_OPT.
;
;	PATH:	Initial path for file browsing when saving reference stars.
;		If the argument of the keyword is a named variable, its value
;		is overwritten.
;
;	GUIDE_X/Y:	Position of AO guide star in pixels
;
;	DEFAULT_PAR:	Structure of default parameters for the widget's form.
;
;	GROUP: XPsf_Extract group leader.
;
;	UVALUE: XPsf_Extract user value.
;
; OUTPUTS:
;	Image:	Same as input Image if no saturated stars are present.
;		Otherwise it is the input Image with corrected saturated stars.
;
;	Psf:	PSF estimate. The size must be specified by the user filling
;		the interactive form
;
;	Psf_fwhm:	FWHM of output PSF
;
;	X, Y:	Coordinates of 'PSF stars'
;
;	Background:	2D array, with the same size as Image, containing an estimate
;		of the background emission
;
; OPTIONAL OUTPUTS:
;	IMAGE_DISPLAY_OPT:	 Set this keyword to a named variable to get
;		the structure of image display options, as defined and/or
;		modified by XPSF_EXTRACT.
;
;	PSF_DISPLAY_OPT:	 Set this keyword to a named variable to get
;		the structure of PSF display options, as defined and/or
;		modified by XPSF_EXTRACT.
;
;	DEFAULT_PAR:	Set this keyword to a named variable to get the
;		structure of parameters set by the widget's user.
;
; SIDE EFFECTS:
;	Initiates the XMANAGER if it is not already running.
;
; RESTRICTIONS:
;	The Help menu opens the file
;	'/starfinder/xpsf_extract_help.txt'.
;
; PROCEDURE:
;	Create and register the widget as a modal widget.
;	Then let the user define and or/modify the PSF extraction options and apply
;	them to the input image. As a PSF estimate is obtained applying the current
;	options, it is displayed on the graphic window. Then the user may exit or
;	repeat the extraction procedure with different parameters.
;
; MODIFICATION HISTORY:
;	Written by: Emiliano Diolaiti, September 1999
;	Updates:
;	1) Enhanced error handling in event-handler
;	   (Emiliano Diolaiti, April 2000).
;	2) Added experimental support for spatially variant PSF
;	   (Rainer Koehler, May 2001)
;-

; XPSF_EXTRACT_GET_PRINCIPAL: auxiliary routine to select 'PSF stars'.

PRO xpsf_extract_get_principal, papa, image, wnum, display_opt, upper_lev, $
				x_in, y_in, x, y, same_stars

	on_error, 2
	same_stars = 0B
	if  n_elements(x_in) ne 0 and n_elements(y_in) ne 0  then begin
	   msg = dialog_message('Do you want to use the same stars as before?', /QUESTION)
	   if  strlowcase(msg) eq 'yes'  then begin
	      x = x_in  &  y = y_in  &  same_stars = 1B  &  return
	   endif
	endif
	; Select stars
	display_image, image, wnum, OPTIONS = display_opt
   	id = dialog_message(['Select the stars to form the PSF.', '', $
   	   		     'Use the left button of your mouse; ' + $
   	  		     'press the right button to exit.'], /INFO, DIALOG_PARENT=papa)
	if  n_elements(upper_lev) ne 0  then  upper = upper_lev
	click_on_max, image, /MARK, /SILENT, UPPER = upper, $
	              SYMSIZE = 3, x_click, y_click
	nstars = n_elements(x_click)
	if  nstars eq 0  then  return
	; Is there at least one unsaturated star?
	if  n_elements(upper_lev) ne 0  then begin
	   w = where(image[x_click, y_click] lt upper_lev, count)
	   if  count eq 0  then begin
   	      id = dialog_message(/ERROR, 'Please select at least one unsaturated star.')
   	      return
   	   endif
	endif
	; Sort them in order of decreasing intensity
	x = x_click  &  y = y_click
	if  nstars ne 0  then begin
	   sorted = reverse(sort(image[x, y]))  &  x = x[sorted]  &  y = y[sorted]
	endif
	return
end

; XPSF_EXTRACT_CONFIRM: auxiliary routine to select secondary sources.

PRO xpsf_extract_confirm, image, wnum, display_opt, x_in, y_in, $
			  same_stars, psfsize, x_out, y_out

	on_error, 2
	if  n_elements(x_in) eq 0 or n_elements(y_in) eq 0  then  return
   	if  same_stars  then begin
   	   x_out = x_in  &  y_out = y_in  &  return
   	endif
   	sub_arrays, image, x_in, y_in, psfsize, stack
   	nstars = n_elements(x_in)
   	for  n = 0L, nstars - 1  do begin
   	   xn = -1  &  yn = -1
   	   opt = default_display_opt(stack[*,*,n])
   	   opt.reverse = display_opt.reverse
   	   opt.stretch = display_opt.stretch
   	   opt.color_table = display_opt.color_table
   	   display_image, stack[*,*,n], wnum, OPTIONS = opt
   	   msg = dialog_message('Confirm this star?', /QUESTION)
   	   if  strlowcase(msg) eq 'no'  then begin
   	      x_in[n] = -1  &  y_in[n] = -1
   	   endif
   	endfor
   	w = where(x_in ge 0 and y_in ge 0, n_confirm)
   	if  n_confirm ne 0  then begin
   	   x_out = x_in[w]  &  y_out = y_in[w]
   	endif
	display_image, image, wnum, OPTIONS = display_opt
	return
end

; XPSF_EXTRACT_GET_SECONDARY: auxiliary routine to select secondary sources.

PRO xpsf_extract_get_secondary, papa, image, wnum, display_opt, x, y, $
				same_stars, psfsize, x2_in, y2_in, x2, y2

  	on_error, 2
	if  n_elements(x) eq 0 or n_elements(y) eq 0  then  return
	msg = dialog_message(['Do you want to select and subtract the ', $
			      'secondary sources around the selected stars?'], $
                             /QUESTION, DIALOG_PARENT=papa)
	if  strlowcase(msg) eq 'no'  then  return
	if  same_stars and n_elements(x2_in) ne 0 and n_elements(y2_in) ne 0  then begin
	   msg = dialog_message('Select the same secondary sources as before?', /QUESTION)
	   if  strlowcase(msg) eq 'yes'  then begin
	      x2 = x2_in  &  y2 = y2_in  &  return
	   endif
	endif
   	sub_arrays, image, x, y, psfsize, stack
   	nstars = n_elements(x)
   	for  n = 0L, nstars - 1  do begin
   	   xn = -1  &  yn = -1
   	   opt = default_display_opt(stack[*,*,n])
   	   opt.reverse = display_opt.reverse
   	   opt.stretch = display_opt.stretch
   	   opt.color_table = display_opt.color_table
   	   display_image, stack[*,*,n], wnum, OPTIONS = opt
   	   msg = dialog_message(['Select the main secondary sources around ' +  $
   	   			 'the displayed star.', '', 'Use the left '  +  $
   	   			 'button of your mouse; push the right button ' + $
   	   			 'to exit.'], /INFO)
	   click_on_max, stack[*,*,n], /MARK, /SILENT, $
	                 BOXSIZE = 3, SYMSIZE = 3, xn, yn
	   if  xn[0] ne -1 and yn[0] ne -1  then begin
	      xn = xn + x[n] - psfsize/2  &  yn = yn + y[n] - psfsize/2
	      x2 = append_elements(x2, xn)
	      y2 = append_elements(y2, yn)
	   endif
   	endfor
	; Sort secondary stars in order of decreasing intensity
   	if  n_elements(x2) ne 0  then begin
	   sorted = reverse(sort(image[x2, y2]))
	   x2 = x2[sorted]  &  y2 = y2[sorted]
	endif
	; Restore previous display
	display_image, image, wnum, OPTIONS = display_opt
	return
end

; XPSF_EXTRACT_EVENT: XPsf_Extract event handler.

PRO xpsf_extract_event, event

	catch, error
	if  error ne 0  then begin
	   msg = dialog_message(/ERROR, !err_string)
	   widget_control, event.id, SET_UVALUE = data, /NO_COPY
	   return
	endif
	widget_control, event.id, GET_UVALUE = data, /NO_COPY
	event_type = strlowcase(event.tag)
	case  event_type  of
            'upper_lev': begin
	        widget_control, event.id, GET_VALUE = form
                image_max = max(*(*data).image)
                for  id = 12, 14  do $
                  widget_control, (*data).ids[id], $
                  SENSITIVE = form.upper_lev le image_max and 1B
            end
            'guide_x': begin
                widget_control, event.id, GET_VALUE = form
                *(*data).guide_x = form.guide_x
            end
            'guide_y': begin
                widget_control, event.id, GET_VALUE = form
                *(*data).guide_y = form.guide_y
            end
            'click_gs': begin
                print,"Click on Guide star"
                widget_control, event.id, GET_VALUE = form
                satur = form.upper_lev le max(*(*data).image)
                if  satur  then  upper_lev = form.upper_lev
                display_image, *(*data).image, (*data).wnum, OPTIONS = *(*data).ima_disp
                click_on_max, *(*data).image, /MARK, N_SELECT=1, /SILENT, UPPER = upper_lev, $
                  SYMSIZE = 3, x_click, y_click
                widget_control, event.id, SET_VALUE = { guide_x: x_click, guide_y: y_click }
                *(*data).guide_x = x_click
                *(*data).guide_y = y_click
            end
            'psf_param': begin
                widget_control, event.id, GET_VALUE = form
                print,"psf_size is", form.psf_size
                if  form.psf_size eq 0  then begin
                    msg = dialog_message(/ERROR, 'Please select a PSF size.', DIALOG_PARENT=event.top)
                endif else begin
                    print,"psf_size is", form.psf_size
                    estimate_svpsf, *(*data).image, form.psf_thres, 2*(form.psf_size), $
                      *(*data).guide_x, *(*data).guide_y, PATH = *(*data).path
                endelse
            end
	   'go': begin
	      widget_control, event.id, GET_VALUE = form
	      if  form.psf_size ne 0  then begin
	         ; Define input parameters of PSF_EXTRACT
	         psf_size = form.psf_size
	         n_fwhm_back = form.n_fwhm_back
	         n_fwhm_fit = form.n_fwhm_fit
	         norm_max = form.norm_max
	         weigh_med = form.weigh_med
	         satur = form.upper_lev le max(*(*data).image)
	         if  satur  then  upper_lev = form.upper_lev
	         n_fwhm_match = form.n_fwhm_match
	         n_width = form.n_width
	         mag_fac = form.mag_fac
	         ; Save parameters
	         (*data).par.psf_size = psf_size
	         (*data).par.n_fwhm_back = n_fwhm_back
	         (*data).par.n_fwhm_fit = n_fwhm_fit
	         (*data).par.norm_max = norm_max
	         (*data).par.weigh_med = weigh_med
	         (*data).par.upper_lev = form.upper_lev
	         (*data).par.n_fwhm_match = n_fwhm_match
	         (*data).par.n_width = n_width
	         (*data).par.mag_fac = mag_fac
	         ; Select 'PSF stars'
	         xpsf_extract_get_principal, event.top, *(*data).image, (*data).wnum, *(*data).ima_disp, $
	            			upper_lev, *(*data).x, *(*data).y, x_0, y_0, same_stars
	         xpsf_extract_confirm, *(*data).image, (*data).wnum, *(*data).ima_disp, $
	                        x_0, y_0, same_stars, psf_size, x, y
	         xpsf_extract_get_secondary, event.top, *(*data).image, (*data).wnum, *(*data).ima_disp, $
	            			x, y, same_stars, psf_size, *(*data).x2, *(*data).y2, x2_0, y2_0
	         ; Estimate PSF
	         if  n_elements(x) ne 0 and n_elements(y) ne 0  then begin
	            *(*data).x = x  &  *(*data).y = y
	            if  n_elements(x2_0) ne 0 and n_elements(y2_0) ne 0  then begin
	               compare_lists, x, y, x2_0, y2_0, MAX_DISTANCE = sqrt(2) * 1.5, $
	                              x_1, y_1, x2_1, y2_1, SUB2 = s2
	               if  s2[0] ge 0  then begin
	                  x2 = x2_0[s2]  &  y2 = y2_0[s2]
	                  *(*data).x2 = x2  &  *(*data).y2 = y2
	               endif
	            endif
	            widget_control, /HOURGLASS
	            psf_extract, *(*data).x, *(*data).y, x2, y2, *(*data).image, $
	               psf_size, *(*data).psf, psf_fwhm, *(*data).background, $
		           N_FWHM_BACK = n_fwhm_back, N_FWHM_FIT = n_fwhm_fit, $
		           INTERP_TYPE = 'I', UPPER_LEVEL = upper_lev, $
		           N_FWHM_MATCH = n_fwhm_match, N_WIDTH = n_width, $
	               MAG_FAC = mag_fac, UNWEIGHTED = (weigh_med eq 0) and 1B, $
	               NORM_MAX = (norm_max eq 1) and 1B
		        ; Save outputs
		        if  n_elements(psf_fwhm) ne 0  then begin
		           *(*data).psf_fwhm = psf_fwhm
	               msg = dialog_message(/INFO, 'PSF extracted', DIALOG_PARENT=event.top)
		        endif
	         endif
	      endif else $
	         msg = dialog_message(/ERROR, 'Please select a PSF size.', DIALOG_PARENT=event.top)
	      end
	   'disp_ima': begin
	      widget_control, /HOURGLASS
	      display_image, *(*data).image, (*data).wnum, OPTIONS = *(*data).ima_disp
	      (*data).last_disp = (*data).image
	      (*data).last_disp_opt = (*data).ima_disp
	      end
	   'disp_psf': if  n_elements(*(*data).psf) ne 0  then begin
	      widget_control, /HOURGLASS
	      display_image, *(*data).psf, (*data).wnum, OPTIONS = *(*data).psf_disp
	      (*data).last_disp = (*data).psf
	      (*data).last_disp_opt = (*data).psf_disp
	      endif
	   'disp_opt': if  n_elements(*(*data).last_disp) ne 0  then $
	      *(*data).last_disp_opt = xdisplayopt(*(*data).last_disp, (*data).wnum, $
	      			OPTIONS = *(*data).last_disp_opt, GROUP = event.top)
	   'help': $
	      xdispfile, file_name('starfinder', 'xpsf_extract_help.txt'), $
	      		 TITLE = 'XPsf_Extract help', /MODAL
	   'exit': begin
	      if  n_elements(*(*data).x) ne 0  then begin
	         msg = dialog_message(/QUESTION, 'Save PSF stars?', DIALOG_PARENT=event.top)
	         if  strlowcase(msg) eq 'yes'  then begin
	            file = dialog_pickfile(/WRITE, FILTER = '*.txt', $
                                           PATH = *(*data).path, GET_PATH = path)
	            if  file ne ''  then begin
	               widget_control, /HOURGLASS
	               if  strpos(file, '.txt') lt 0  then  file = file + '.txt'
	               *(*data).path = path
	               out = [transpose(*(*data).x), transpose(*(*data).y)]
	               openw, lun, file, /GET_LUN
	               printf, lun, out  &  free_lun, lun
	            endif
	         endif
	      endif
	      widget_control, event.id, SET_UVALUE = data, /NO_COPY
	      widget_control, event.top, /DESTROY
	      end
	   else:
	endcase
	if  event_type ne 'exit'  then $
	   widget_control, event.id, SET_UVALUE = data, /NO_COPY
	return
end

; XPSF_EXTRACT_DEF: define data structure.

FUNCTION xpsf_extract_def, ids, par, image, wnum, guide_x, guide_y, ima_disp, psf_disp, path

	return, { ids: ids, par: par, $
			  image: ptr_new(image, /NO_COPY), $
			  psf: ptr_new(/ALLOCATE), psf_fwhm: ptr_new(/ALLOCATE), $
			  x: ptr_new(/ALLOCATE), y: ptr_new(/ALLOCATE), $
			  x2: ptr_new(/ALLOCATE), y2: ptr_new(/ALLOCATE), $
			  background: ptr_new(/ALLOCATE), $
			  wnum: wnum, $
                  	  guide_x: ptr_new(guide_x,/NO_COPY), guide_y: ptr_new(guide_y,/NO_COPY), $
			  ima_disp: ptr_new(ima_disp, /NO_COPY), $
			  psf_disp: ptr_new(psf_disp, /NO_COPY), $
			  last_disp: ptr_new(/ALLOCATE), last_disp_opt: ptr_new(/ALLOCATE), $
			  path: ptr_new(path, /NO_COPY) }
end

; XPSF_EXTRACT_DEL: de-reference and de-allocate heap variables.

PRO xpsf_extract_del, data, par, image, psf, psf_fwhm, x, y, background, $
                      guide_x, guide_y, ima_disp, psf_disp, path

	par = (*data).par
	image = *(*data).image
	if  n_elements(*(*data).psf) ne 0  then  psf = *(*data).psf
	if  n_elements(*(*data).psf_fwhm) ne 0  then  psf_fwhm = *(*data).psf_fwhm
	if  n_elements(*(*data).x) ne 0 and n_elements(*(*data).y) ne 0  then begin
	   x = *(*data).x  &  y = *(*data).y
	endif
	if  n_elements(*(*data).background) ne 0  then  background = *(*data).background
	if  n_elements(*(*data).guide_x)  ne 0  then  guide_x  = *(*data).guide_x
	if  n_elements(*(*data).guide_y)  ne 0  then  guide_y  = *(*data).guide_y
	if  n_elements(*(*data).ima_disp) ne 0  then  ima_disp = *(*data).ima_disp
	if  n_elements(*(*data).psf_disp) ne 0  then  psf_disp = *(*data).psf_disp
	if  n_elements(*(*data).path) ne 0  then  path = *(*data).path
	ptr_free, (*data).image, (*data).psf, (*data).psf_fwhm, $
			(*data).x, (*data).y, (*data).x2, (*data).y2, $
			(*data).background, (*data).guide_x, (*data).guide_y, $
			(*data).ima_disp, (*data).psf_disp, $
			(*data).last_disp, (*data).last_disp_opt, (*data).path
	ptr_free, data
	return
end

; XPSF_EXTRACT_PAR: define default parameters.

PRO xpsf_extract_par, id, par, image_max

	if  n_elements(par) ne 0  then begin
	   psf_size = par.psf_size
	   n_fwhm_back = par.n_fwhm_back
	   n_fwhm_fit = par.n_fwhm_fit
	   norm_max = par.norm_max
	   weigh_med = par.weigh_med
	   upper_lev = par.upper_lev
	   n_fwhm_match = par.n_fwhm_match
	   n_width = par.n_width
	   mag_fac = par.mag_fac
	endif else begin
	   psf_size = 0
	   n_fwhm_back = 9
	   n_fwhm_fit = 2
	   norm_max = 1
	   weigh_med = 0
	   upper_lev = 1e6
	   while  upper_lev le image_max  do  upper_lev = 10 * upper_lev
	   n_fwhm_match = 1
	   n_width = 3
	   mag_fac = 2
	   par = {psf_size: psf_size, n_fwhm_back: n_fwhm_back, n_fwhm_fit: n_fwhm_fit, $
	   		  norm_max: norm_max, weigh_med: weigh_med, upper_lev: upper_lev, $
	   		  n_fwhm_match: n_fwhm_match, n_width: n_width, mag_fac: mag_fac}
	endelse
	init = { psf_size: strcompress(string(psf_size), /REMOVE_ALL), $
			 n_fwhm_back: strcompress(string(n_fwhm_back), /REMOVE_ALL), $
			 n_fwhm_fit: strcompress(string(n_fwhm_fit), /REMOVE_ALL), $
			 norm_max: norm_max, weigh_med: weigh_med, $
			 upper_lev: strcompress(string(upper_lev), /REMOVE_ALL), $
			 n_fwhm_match: strcompress(string(n_fwhm_match), /REMOVE_ALL), $
			 n_width: strcompress(string(n_width), /REMOVE_ALL), $
			 mag_fac: strcompress(string(mag_fac), /REMOVE_ALL) }
	widget_control, id, SET_VALUE = init
	return
end

; XPSF_EXTRACT: XPsf_Extract widget definition module.

PRO xpsf_extract, image, psf, psf_fwhm, x, y, background, $
                  IMAGE_DISPLAY_OPT = ima_disp, PSF_DISPLAY_OPT = psf_disp, $
                  GUIDE_X = guide_x, GUIDE_Y = guide_y, $
                  PATH = path, DEFAULT_PAR = par, GROUP = group, UVALUE = uvalue

	;catch, error
	;if  error ne 0  then begin
	;   xpsf_extract_del, data, par, image, psf, psf_fwhm, x, y, background, $
	;                                     ima_disp, psf_disp, path
	;   if  n_elements(group) eq 0  then  widget_control, group_id, /DESTROY
	;   return
	;endif
	; Create group leader if necessary
	if  n_elements(group) eq 0  then $
	   group_id = widget_base()  else  group_id = group
	; Create modal base
	if  n_elements(uvalue) eq 0  then  uvalue = 0B
	base = widget_base(TITLE = 'XPsf_Extract', /MODAL, UVALUE= uvalue, COLUMN= 2, $
                           GROUP_LEADER = group_id, XOFFSET=180, YOFFSET=100 )
	left_base = widget_base(base, /GRID_LAYOUT)
	right_base = widget_base(base, /GRID_LAYOUT)
	; Define draw window (in the right part of base)
	s = round(0.7 * min(get_screen_size()))
	draw = widget_draw(right_base, SCR_XSIZE = s, SCR_YSIZE = s, $
					   /ALIGN_CENTER, RETAIN = 2)
	; Define form with PSF extraction parameters
	desc = [ $
	'0, LABEL,Boxes:,LEFT', $
	'1, BASE,,FRAME,COLUMN', $
	'0, INTEGER,,LABEL_LEFT=Size of output PSF,TAG=psf_size', $
	'0, FLOAT,,LABEL_LEFT=Box size for background estimation (FWHM units),' + $
	   'TAG=n_fwhm_back', $
	'2, FLOAT,,LABEL_LEFT=Fitting box size (FWHM units),TAG=n_fwhm_fit', $
	'0, LABEL,Options:,LEFT', $
	'1, BASE,,FRAME,COLUMN', $
	'0, BUTTON,unit flux|unit maximum,EXCLUSIVE,' + $
	   'LABEL_TOP=Normalize PSF stars to:,NO_RELEASE,ROW,TAG=norm_max', $
	'2, BUTTON,unweighted|weighted,EXCLUSIVE, ' + $
	   'LABEL_TOP=Median superposition:,NO_RELEASE,ROW,TAG=weigh_med', $
	'0, LABEL,Saturated stars:,LEFT', $
	'1, BASE,,FRAME,COLUMN', $
	'0, FLOAT,,LABEL_LEFT=Saturation threshold,WIDTH=12,TAG=upper_lev', $
	'0, FLOAT,,LABEL_LEFT=Search box to optimize correlation (FWHM units),' + $
	   'TAG=n_fwhm_match', $
	'0, FLOAT,,LABEL_LEFT=Repair box (saturated core units),TAG=n_width', $
	'2, INTEGER,,LABEL_LEFT=Sub-pixel positioning accuracy,TAG=mag_fac', $
        '0, LABEL,AO Guide Star:,LEFT', $
        '1, BASE,,FRAME,COLUMN', $
        '1, BASE,,,ROW', $
        '0, INTEGER,,LABEL_LEFT=X:,TAG=guide_x', $
        '2, INTEGER,,LABEL_LEFT=Y:,TAG=guide_y', $
	'2, BUTTON,Click on image to mark it,NO_RELEASE,TAG=click_gs', $
        '0, LABEL,Spatially variant PSF:,LEFT', $
        '1, BASE,,FRAME,COLUMN', $
        '0, FLOAT,,LABEL_LEFT=Threshold for star selection,WIDTH=12,TAG=psf_thres', $
        '2, BUTTON,Determine parameters,NO_RELEASE,TAG=psf_param', $
	'1, BASE,,ROW', $
	'2, BUTTON,Processing...,NO_RELEASE,TAG=go', $
	'1, BASE,,ROW', $
	'0, BUTTON,Display Image,NO_RELEASE,TAG=disp_ima', $
	'0, BUTTON,Display PSF,NO_RELEASE,TAG=disp_psf', $
	'2, BUTTON,Display Options,NO_RELEASE,TAG=disp_opt', $
	'1, BASE,,ROW', $
	'0, BUTTON,Help,NO_RELEASE,TAG=help', $
	'2, BUTTON,Exit,QUIT,NO_RELEASE,TAG=exit']
	form = cw_form(left_base, desc, /COLUMN, IDS = ids)
	image_max = max(image)
	xpsf_extract_par, form, par, image_max
	for  id = 12, 14  do $
	   widget_control, ids[id], SENSITIVE = par.upper_lev le image_max and 1B
	; Realize widget
	widget_control, base, /REALIZE
	; Display image and define display options
	widget_control, draw, GET_VALUE = wnum
	display_image, image, wnum, OPTIONS = ima_disp
	; Define pointer to auxiliary/output data
	data = xpsf_extract_def(ids, par, image, wnum, guide_x, guide_y, ima_disp, psf_disp, path)
	data = ptr_new(data, /NO_COPY)
	(*data).last_disp = (*data).image
	(*data).last_disp_opt = (*data).ima_disp
	widget_control, form, SET_UVALUE = data
	; Register
	xmanager, 'xpsf_extract', base, EVENT_HANDLER = 'xpsf_extract_event'

        print,"guide pos: ",*(*data).guide_x,*(*data).guide_y

	; De-reference output data and de-allocate heap variables
	xpsf_extract_del, data, par, image, psf, psf_fwhm, x, y, background, $
			  guide_x, guide_y, ima_disp, psf_disp, path
	; Destroy group leader if necessary
	if  n_elements(group) eq 0  then $
	   widget_control, group_id, /DESTROY
	return
end
