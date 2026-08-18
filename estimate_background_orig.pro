; $Id: estimate_background.pro, v 1.0 Aug 1999 e.d. $
;
;+
; NAME:
;	ESTIMATE_BACKGROUND
;
; PURPOSE:
;	Call IMAGE_BACKGROUND to estimate intensity distribution of the
;	background in a given image. If an error occurs, estimate the
;	background emission by median smoothing of the input image.
;
; CATEGORY:
;	Signal processing.
;
; CALLING SEQUENCE:
;	Result = ESTIMATE_BACKGROUND(Image, Step)
;
; INPUTS:
;	Image:	2D array
;
;	Step:	Size of sub-regions to measure local background or box size
;		for median smoothing of the Image
;
; KEYWORD PARAMETERS:
;	SKY_MEDIAN:	Set this keyword to a nonzero value to estimate the
;		background directly by median smoothing of Image
;
;	_EXTRA:	All the input keywords supported by IMAGE_BACKGROUND
;
; OUTPUTS:
;	Result:	2D array, having the same size as the input Image.
;
; RESTRICTIONS:
;	All the restrictions described in IMAGE_BACKGROUND, if the default
;	method is used.
;	If median smoothing is used, it should be noticed that this technique
;	tends to overestimate the local background level, especially in the
;	presence of bright point sources.
;
; MODIFICATION HISTORY:
; 	Written by:	Emiliano Diolaiti, August 1999.
;       Modified:
;         1) return shift(b,1,1) - to remedy shift of backgroudn compared to real image
;            Rainer Schoedel, July 2023
;-

FUNCTION estimate_background, image, step, SKY_MEDIAN = sky_median, _EXTRA = extra

	on_error, 2
	if  keyword_set(sky_median) then begin
            print, "estimate_background using median_filter"
            b = median_filter(image, step)
        endif else begin
            print, "estimate_background using image_background"
            b = image_background(image, step, _EXTRA = extra)
            if  n_elements(b) eq 1  then begin
                message, 'unable to estimate background; trying with median smoothing', /INFO
                b = median_filter(image, step)
            endif
        endelse
	return, shift(b,1,1)
;	return, b
end
