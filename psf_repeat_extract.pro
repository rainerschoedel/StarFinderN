;
; psf_repeat_extract.pro
; Created:     Wed May  2 18:30:37 2001 by Koehler@hex.ucsd.edu
; Last change: Wed May 16 15:10:01 2001
;
; PURPOSE:
;	re-extract psf after analyzing the image
;
; CALLING SEQUENCE:
;	psf_repeat_extract, x_psf, y_psf, x_stars, y_stars, f_stars, $
;			    image, background, det_stars, psf, $
;			    norm_max, unweighted, saturation
;
; INPUT:
;	x_psf, y_psf	  coordinates of stars used for psf extraction
;	x_stars, y_stars  coordinates of all stars found by starfinder
;       f_stars           fluxes of the stars found by starfinder
;	image		  2D image to analyse
;	background	  2D image of the background
;	det_stars	  synthetic image containing the stars found by starfinder
;	psf		  2D image containing an initial estimate of the psf
;			 (used to subtract the psf-stars from det_stars before
;			  subtracting det_stars from image to remove contaminating sources)
;	norm_max,
;	unweighted	  parameters passed to superpose_stars
;	sat_level	  saturation level
;
; RETURNS:
;	better estimate for the psf, normalized to unit flux
;
FUNCTION psf_repeat_extract, x_psf, y_psf, x_stars, y_stars, f_stars, $
			image, background, det_stars, psf, $
			norm_max, unweighted, sat_level


	siz = size52(image, /DIM)
	compare_lists, x_psf, y_psf, x_stars, y_stars, $
	               aux1, aux2, x_psf2, y_psf2, SUBSCRIPTS_2 = w
	f_psf = f_stars[w]
	other_stars = det_stars - $
	              image_model(x_psf2, y_psf2, f_psf, siz[0], siz[1], psf, INTERP = 'I')

	if  sat_level le max(image)  then  saturation = sat_level

	new_psf= superpose_stars(image - background - other_stars, $
				 x_psf2, y_psf2, (size52(psf, /DIM))[0], $
				 SATURATION = saturation, NORM_MAX = norm_max, $
				 UNWEIGHTED = unweighted, INTERP = 'I')

	return, new_psf / total(new_psf)
end
