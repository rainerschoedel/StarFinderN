;
; NAME:
;	estimate_svpsf
;
; PURPOSE:
;	Estimate parameters that describe the spatial variation of the PSF.
;
;	This is experimental, the general idea is:
;	Take an image that was background-subtracted and
;	deconvoled with the on-axis PSF (using Richardson-Lucy).
;	Find stars brighter than a given threshold.
;	Fit a Gaussian to these stars and record the parameters.
;	Fit some simple function of azimuth and distance to guide star
;	to these parameters.
;
; Last Change: Fri Mar  1 18:13:13 2002
;

PRO estimate_svpsf, $
	image, threshold, box_size, guide_x, guide_y, PATH = path

	openw,fp, path + "/svpsf.txt",/get_lun
	search_objects, image, threshold, n_max, x0, y0, i0
	print, "Found ", n_max, " maxima"
	msg = dialog_message('Found '+string(n_max)+' maxima.  Do you want to continue?', /QUESTION)

	if  strlowcase(msg) eq 'yes'  then begin
	  printf, fp, "Found ", n_max, " maxima"
	  printf, fp, "Guide stars at", guide_x, ",", guide_y

          dx = x0 - guide_x
          dy = y0 - guide_y
          ;; angle is measured clockwise in gauss2drotfit!
          ph = -atan( dy, dx ) * 180./!Pi
          r  = sqrt(dx*dx + dy*dy)

          wr_arr = fltarr(n_max,/NOZERO)
          wa_arr = fltarr(n_max,/NOZERO)

	  for n = 0L, n_max-1  do begin

	    print,    FORMAT = '("Star ", I4, " at ", I4, ",", I4, ", r = ", F, ", phi = ",F)', $
					  n, 	      x0[n],   y0[n],	     r[n],	   ph[n]
	    printf,fp,FORMAT = '("Star ", I4, " at ", I4, ",", I4, ", r = ", F, ", phi = ",F)', $
					  n,	      x0[n],   y0[n],	     r[n],	   ph[n]

	    box = sub_array(image, box_size, REFERENCE = [ x0[n], y0[n] ])
	    junk= gauss2drotfit(box,ph[n],gausspar)
	    print,    "     wr =",string(gausspar[2]),", wa =",string(gausspar[3]),", angle =",string(gausspar[6] * 180./!Pi)
	    printf,fp,"     wr =",string(gausspar[2]),", wa =",string(gausspar[3]),", angle =",string(gausspar[6] * 180./!Pi)

            if  (abs( ph[n] - gausspar[6]*180./!Pi) gt 15.)  then begin
                print, " deviates from radial direction"
                wr_arr[n] = -1.
                wa_arr[n] = -1.
            endif else begin
                wr_arr[n] = abs(gausspar[2])
                wa_arr[n] = abs(gausspar[3])
            endelse
	  end
	  close,fp

          good = where(wr_arr ge 0.)
          r_good = r[good]
          wr_arr = wr_arr[good]
          wa_arr = wa_arr[good]

          fit_r = linfit( r_good, wr_arr, YFIT = wr_fit )
          print, "fit to radial widths:", fit_r
          xplot, wr_arr, r_good, overplot1 = wr_fit

          fit_a = linfit( r_good, wa_arr, YFIT = wa_fit )
          print, "fit to azim.  widths:", fit_a
          xplot, wa_arr, r_good, overplot1 = wa_fit

	endif
end
