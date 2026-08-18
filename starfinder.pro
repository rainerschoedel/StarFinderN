; $Id: starfinder.pro, v 1.3 Dec 2000 e.d. $
;
;+
; NAME:
;	STARFINDER_NEW
;
; PURPOSE:
;	Given a stellar field and an approximation of the Point Spread Function,
;	(PSF) detect the stellar sources and estimate their position and flux.
;	The image may be contaminated by a smooth non-uniform background emission.
;	If the imaged field is not isoplanatic, it is possible to partition it
;	into approximately isoplanatic sub-regions, provided a local estimate of
;	the PSF is available. In this case, the field is analyzed as a whole as
;	in the constant PSF case, with the only difference that the local PSF is
;	used to analyze each star.
;
;       This new version addresses a problem with possible additive
;       offsets associated to the stars when the PSF estimate is too small.
;
;
;
; CATEGORY:
;	Signal processing. Stellar fields astrometry and photometry.
;
; CALLING SEQUENCE:
;	STARFINDER, Image, Psf, Threshold, Min_correlation, $
;	            X, Y, Fluxes, Offsets, Sigma_x, Sigma_y, Sigma_f,
;                   Sigma_Offsets, Correlation
;
; INPUTS:
;	Image:	2D image of the stellar field
;
;	Psf:	2D array, representing the Point Spread Function of the stellar
;		field. If the PSF is space-variant, Psf may be a 3D stack of local
;		PSF measurements, relative to a partition of the imaged field into
;		sub-regions arranged in a regular grid. In this case it is necessary
;		to supply the bounds of the partition (see keyword SV_PAR).
;
;	Threshold:	Vector of lower detection levels (above the local background,
;		which is temporarly removed before detection). These levels are
;		assumed to be "absolute" levels by default. If the keyword
;		REL_THRESHOLD (see below) is set and the noise standard deviation is
;		defined (see the keyword NOISE_STD) below, then the threshold levels
;		are assumed to be "relative", i.e. expressed in units of the noise
;		standard deviation.
;		Example 1: let Threshold be = [10., 3.]
;			If the keyword REL_THRESHOLD is not defined or the keyword
;			parameter NOISE_STD is undefined, the threshold levels 10 and 3
;			are absolute intensity levels, i.e. all the peaks brighter than 10
;			and 3 counts are considered as presumed stars. If REL_THRESHOLD is
;			set and NOISE_STD is defined, the intensity levels for detection
;			are respectively (10 * NOISE_STD) and (3 * NOISE_STD).
;		The number of elements of the vector Threshold establishes the number
;		of iterations of the "basic step" (see PROCEDURE below).
;		The components of the vector Threshold may be all equal or decreasing.
;
;	Min_correlation:	Minimum value of correlation between an acceptable
;		stellar image and the Psf. It must be > 0 and < 1.
;
; KEYWORD PARAMETERS:
;	SV_PAR:	Set this keyword to a structure defining the bounds of the
;		imaged field partition when the PSF is not isoplanatic.
;		Let the imaged field be partitioned into Nx*Ny sub-regions, such
;		that the (j, i)-th region is bounded by
;		Lx[j] < x < Ux[j], Ly[i] < y < Uy[i], where
;		j = 0, ..., Nx - 1; i = 0, ..., Ny - 1.
;		The structure must be defined as follows:
;		SV_PAR = {Lx: Lx, Ux: Ux, Ly: Ly, Uy: Uy}.
;		The (j, i)-th sub-region must correspond to the k-th psf in the 3D
;		stack, where k = i*Nx + j.
;
;	REL_THRESHOLD:	Set this keyword to specify that the detection levels
;		contained in the input parameter Threshold have to be considered as
;		"relative" levels, i.e. they must be multiplied by the noise standard
;		deviation. This keyword is effective only if the NOISE_STD is defined
;		(see below).
;
;	X_BAD, Y_BAD:	Coordinates of bad pixels to be excluded.
;		It is important to mask bad pixels, especially in the following phases
;		of the analysis:
;		1) search for presumed stars
;		2) correlation check
;		3) local fitting.
;
;	BACKGROUND:	2D array, containing an initial guess of the image background
;		emission. If the keyword is undefined, the background is estimated
;		automatically, provided the box size BACK_BOX (see below) is defined.
;		The background estimate is subtracted before searching for presumed
;		stars in the image and before computing the correlation coefficient.
;
;	BACK_BOX:	Set this keyword to a scalar value specifying the box size
;		to estimate the background emission. For more details see the routine
;		ESTIMATE_BACKGROUND in the file "estimate_background.pro".
;		The value of this keyword may be conveniently defined as a multiple
;		of the PSF Full Width at Half Maximum (e.g. 5 * FWHM).
;		If if is not supplied, the program uses the argument of the keyword
;		BACKGROUND (if defined of course!) as a background estimate. However
;		this will prevent any improvements in the background knowledge in the
;		course of iterations. If the stellar field is supposed to have no
;		background emission, the keywords BACKGROUND and BACK_BOX should be
;		left undefined.
;
;	For other keywords concerning background estimation see the routines
;	IMAGE_BACKGROUND and ESTIMATE_BACKGROUND.
;
;	FOUR:	Set this keyword to identify relative maxima referring only to
;		the 4-neighbors of each pixel. The default is to use 8-neighbors.
;
;	PRE_SMOOTH:	Set this keyword to smooth the image with a standard low-pass
;		filter before searching for local maxima. This reduces the probability
;		to pick up noise spikes, which would increase the computation time for
;		further checks and the probability of false detections.
;		For more details see the procedure SEARCH_OBJECTS, in the file
;		"search_objects.pro".
;
;	MINIF:	If PRE_SMOOTH is set, the keyword MINIF may be used to enter the
;		integer minification factor used to down-sample the image before
;		searching for local maxima, as an alternative smoothing strategy to
;		the standard low-pass filter used by default when PRE_SMOOTH is set.
;
;	CORREL_MAG:	Set this keyword to an integer scalar specifying the sub-pixel
;		accuracy with which the template PSF should be superposed to a given
;		object when computing the correlation coefficient.
;		The default is CORREL_MAG = 1, i.e. the PSF is superposed to the
;		object just taking the maximum intensity pixel as a reference.
;		If CORREL_MAG is > 1, all the possible fractional shifts of the PSF,
;		with step size of 1/CORREL_MAG, are considered.
;		The suggested value is CORREL_MAG = 2 (half pixel positioning).
;		If CORREL_MAG = 1 (or undefined), the correlation threshold set by
;		Min_correlation should not be too high.
;
;	DEBLEND:	Set this keyword to a nonzero value to perform de-blending
;		of the objects detected iterating the basic step (see PROCEDURE).
;		This de-blending strategy allows the algorithm to detect secondary
;		components of crowded groups, whose principal component has previously
;		been detected as a single star. This strategy may be referred to as
;		'partial de-blending'.
;
;	DEBLOST:	Set this keyword to a nonzero value to recover all the
;		significant intensity enhancement lost in the course of the analysis,
;		in order to search for possible blends. This strategy allows the
;		algorithm to re-analyze the blended objects whose principal component
;		has not been previously found as a single star (see DEBLEND above).
;		This strategy, applied after the 'partial de-blending' described with
;		the keyword DEBLEND above, may be referred to as 'full de-blending'.
;		More details can be found in the PROCEDURE description below.
;
;	CUT_THRESHOLD:	Set this keyword to a scalar value in the range ]0, 1[
;		to specify the relative threshold to use when "cutting" a given
;		object to measure its area. The default is CUT_THRESHOLD = 0.2,
;		i.e. the object is cut at 20% of the peak height. Notice that the
;		background is subtracted beforehands. Notice also that if the
;		absolute value of the threshold for binary detection is comparable
;		to the gaussian noise level (see also keywords GAUSSIAN_NOISE and
;		BIN_N_STDEV), the estimated area of the object is not reliable: thus
;		deblending is not applied. This check on the threshold value is
;		performed only if the gaussian noise standard deviation is defined
;		(see the keyword GAUSSIAN_NOISE).
;		For more details on the determination of the area, see the routine
;		PEAK_AREA in the file "peak_area.pro".
;
;	BIN_N_STDEV:	Set this keyword to a positive scalar to specify the
;		minimum cutting threshold for binary detection, in units of the
;		gaussian noise standard deviation. The default value is
;		BIN_N_STDEV = 3.
;
;	BIN_THRESHOLD:	When a crowded group (in the simplest case a close binary
;		star) is analyzed, the deblending algorithm searches for residuals
;		representing secondary components by subtracting the known sources:
;		The brightest local maximum in the residual sub-image is taken as a
;		candidate secondary star. In principle the detection threshold used
;		for isolated objects, set by the parameter Threshold described above,
;		should not be applied in this case, because the residual is affected
;		by the poor knowledge about the subtracted components.
;		BIN_THRESHOLD specifies the relative threshold, in units of the
;		parameter Threshold, to use for the detection of candidate secondary
;		sources in crowded groups. The default is BIN_THRESHOLD = 0, i.e. all
;		the positive residuals (remember that the local background level has
;		been removed!) are considered. Their intensity is compared to the
;		detection threshold after fitting: if the fitted intensity happens to;
;		be below the value set by Threshold, the new secondary component is
;		rejected.
;
;	BIN_TOLERANCE:	An object is classified as "blend" if the relative error;
;		between its area and the area of the PSF is greater than the threshold
;		fixed by this keyword. The default is BIN_TOLERANCE = 0.2, i.e. 20%.
;
;	NOISE_STD:	Set this keyword to a 2D array, with the same size as Image,
;		representing the noise standard deviation in each pixel of the input
;		data. This array is used to compute the formal errors on astrometry
;		and photometry.
;
;	NO_SLANT:	Set this keyword to avoid fitting the local background with
;		a slanting plane. In this case the background to use for the local
;		fit of the stars is derived from the 2D background array and it is
;		kept fixed in the fitting. This option should be used only if the
;		(input) estimate of the image background is very accurate.
;
;	N_ITER:	At the end of the analysis, the detected stars are fitted again
;		a number of times equal to the value specified with this keyword.
;		The default is N_ITER = 1. To avoid re-fitting, set N_ITER = 0.
;		Notice that the final number of re-fitting iterations includes also
;		the extra re-fitting which is normally performed after each basic
;		step (see also the keyword NO_INTERMEDIATE_ITER).
;
;	NO_INTERMEDIATE_ITER:	The currently detected stars are re-fitted after
;		each basic step. Set NO_INTERMEDIATE_ITER to avoid this re-fitting.
;
;	ASTROMETRIC_TOL, PHOTOMETRIC_TOL:	When the last re-fitting is iterated
;		a lot of times, it is possible to stop the iterations when convergence
;		on stellar positions and fluxes is achieved. The default values for
;		convergence are ASTROMETRIC_TOL = 0.01 pixels and
;		PHOTOMETRIC_TOL = 0.01 (i.e. 1%).
;		In practice setting N_ITER = 1 or 2 is generally enough to obtain
;		reliable astrometry and photometry, without having to iterate a lot.
;
; OUTPUTS:
;	X, Y:	Coordinates of detected stars in pixel units.
;		The origin is at (0, 0).
;
;	Fluxes:	Vector of stellar fluxes, referred to the normalization of the Psf.
;
;	Sigma_x, Sigma_y, Sigma_f:	Vector of formal errors on positions and
;		fluxes, estimated by the fitting procedure.
;		These vectors have all components equal to zero if no information is
;		supplied about noise: in this case it has no meaning to estimate the
;		error propagation in the fit.
;
;	Correlation:	Vector of correlation coefficients for accepted stars.
;		Stars belonging to crowded groups detected with the de-blending
;		procedure have a correlation coefficient of -1.
;
; OPTIONAL OUTPUTS:
;	BACKGROUND:	Last estimate of the image background, computed by the
;		program after the iteration corresponding to the lowest
;		detection level.
;
;	STARS:	2D array, containing one shifted scaled replica of the PSF for
;		each detected star.
;
; SIDE EFFECTS:
;	If the keyword NOISE_STD is set to a scalar value it is transformed into
;	a 2D constant array with the same size as the input image.
;
; RESTRICTIONS:
;	1) The algorithm is based on the assumption that the input Image may
;	be considered as a superpositions of stellar sources and a smooth
;	background.
;	2) Saturated stars should have been approximately repaired beforehands.
;	This is especially important for the reliable detection and analysis of
;	fainter sources in their surrounding.
;	3) High accuracy astrometry and photometry are based on sub-pixel
;	positioning of the input PSF. In this version of the algorithm this
;	relies on interpolation techniques, which are not suited to undersampled
;	data. Thus the algorithm, at least in its present form, should not be
;	used with poorly sampled data.
;
; PROCEDURE:
;		The standard analysis is accomplished as a sequence of "basic steps".
;	One of these steps consists of 3 phases:
;	1) detection of presumed stars above a given threshold
;	2) check and analysis of detected objects, sorted by decreasing
;	   intensity
;	3) re_fitting
;	Pixel (x,y) is the approximate center of a presumed star if
;	a) Image(x,y) is a local maximum
;	b) Image(x,y) > Background(x,y) + Stars(x,y) + Threshold,
;	where Image is the stellar field, Background is an approximation of
;	the background emission, Stars is a sum of shifted scaled replicas
;	of the PSF (one for each detected star) and Threshold is the
;	minimum central intensity of a detectable star. In practice the user
;	provides a set of Threshold levels (generally decreasing!): the
;	number of these levels fixes the number of times the basic step is
;	repeated.
;	At the first iteration of the basic step, the "image model" called
;	Stars is identically zero; in later iterations it contains the detected
;	sources. Subtraction of these stars simplifies the detection of fainter
;	objects and allows a better estimation of the image Background.
;	It should be noticed that the model of detected stars (Stars) is
;	subtracted only in order to detecte new presumed stars and refine the
;	background, whereas the subsequent astrometric and photometric analysis
;	is performed on the original Image.
;		Let us describe in detail how the presumed stars are analyzed (Phase
;	2 of each basic step).
;	First of all each object in the newly formed list is "re-identified",
;	i.e. searched again after subtraction of other brighter sources: this
;	allows to reject many spurious detections associated to PSF features
;	of bright stars. The object is compared with the PSF by a correlation
;	check and accepted only if a sufficient similarity is found. Then it is
;	fitted to estimate its position and flux. The local fitting is performed
;	by FITSTARS (see the file "fitstars.pro" for more details), which takes
;	into consideration all the following contributions:
;	1) other known stars in the fitting box, which are fitted along with
;	the object under examination (multiple fitting)
;	2) known stars lying outside the fitting box: this term is extracted
;	from the image model Stars and considered as a fixed contribution
;	3) the local background, which may be approximated either with a
;	slanting plane (whose coefficients are optimized as well) or with a
;	sub-image extracted from the image Background (kept fixed).
;	If the fit is successful, the parameters of the stars are saved and
;	the image model Stars is updated.
;		The basic step (phases 1 + 2 + 3) may be iterated: a new list of
;	objects is formed by searching in the image after subtraction of the
;	previously detected stars. Then the analysis proceeds on the original
;	frame. This iteration is very useful to detect hidden objects, e.g.
;	close binaries down to separations comparable to 1 PSF FWHM.
;		An optional deblending strategy is available, consisting of two
;	separate phases. The first step (see keyword DEBLEND) consists of a search
;	for secondary sources around the objects detected in the earlier phases of
;	the analysis; in the second step (see keyword DEBLOST) all the significant
;	intensity enhancement previously discarded are recovered and a check is
;	performed in order to find among these some possible blends. Blends are
;	recognized on the basis of their larger extension as compared to the PSF.
;	The area of a given object is measured by a thresholding technique, applied
;	at a specified threshold below the peak. When an object is recognized as a
;	blend, deblending is attempted iteratively by searching for a new residual
;	and subsequent fitting. The iteration is stopped when no more residual is
;	found or the fitting of the last residual is not successful. The deblending
;	procedure is applied at the end of the last iteration of the basic step
;	described above, i.e. when all the "resolved" objects are supposed to have
;	been detected.
;
; MODIFICATION HISTORY:
; 	Written by:	Emiliano Diolaiti, August-September 1999.
;	Updates:
;	1) New partial deblending strategy (Emiliano Diolaiti, October 1999).
;	2) Full deblending strategy (Emiliano Diolaiti, February 2000).
;	3) Added PSF stack option; this version might not handle properly
;	   very close groups of objects lying on the boundary of two adjacent
;	   sub-regions (Emiliano Diolaiti, February 2000).
;	4) Modified keyword parameters in auxiliary routines to avoid trouble
;	   under IDL 5.0 (Emiliano Diolaiti, May 2000).
;	5) Modified STARFINDER_FIT module. Now faster.
;	   (Emiliano Diolaiti, December 2000).
;	6) added logfile and experimental support for spatially
;	   variant psf (Rainer Koehler, May 2001)
;       7) Combined with a modification in fitstars.pro, 
;          the local background fitted underneath a star
;          is incorporated into the background estimate.
;          No background should be fitted when estim_bg = 0
;          back_box will be set to PSF fitting box when it is
;          undefined and estim_bg = 1 (Rainer Schoedel, March 2014)
;-





;;; Auxiliary procedures/functions to handle the data structure
;;; representing the list of stars.

; STAR: define a structure containing information on a single star.

FUNCTION star

	return, {starlet, $
			 x: 0., sigma_x: 0., $		; x- coordinate and error
			 y: 0., sigma_y: 0., $		; y- coordinate and error
			 f: 0., sigma_f: 0., $		; flux and error
			 c: -1., $					; correlation
			 is_a_star: 0B}				; flag
end

; CREATE_LIST: create a new list of structured elements representing stars.

FUNCTION create_list, n, x, y, f

	on_error, 2
	element = star()
	list = replicate(element, n)
	if  n_elements(x) ne 0 and n_elements(y) ne 0  then $
	   update_list, list, x, y, f
	return, list
end

; UPDATE_LIST: update the elements of list subscripted by s.
; Set the flag is_a_star to true if /IS_STAR is set.

PRO update_list, list, SUBSCRIPTS = s, x, y, f, c, $
				 sigma_x, sigma_y, sigma_f, IS_STAR = is_star

	on_error, 2
	n = n_elements(s)
	if  n eq 0  then  s = lindgen(n_elements(x))	; update all
	if  s[0] ge 0  then begin
	   list[s].x = x  &  list[s].y = y
	   if  n_elements(f) ne 0  then  list[s].f = f
	   if  n_elements(c) ne 0  then  list[s].c = c
	   if  n_elements(sigma_x) ne 0  then  list[s].sigma_x = sigma_x
	   if  n_elements(sigma_y) ne 0  then  list[s].sigma_y = sigma_y
	   if  n_elements(sigma_f) ne 0  then  list[s].sigma_f = sigma_f
	   list[s].is_a_star = keyword_set(is_star) and 1B
	endif
	return
end

; CREATE_ELEMENT: create and initialize a new element.

FUNCTION create_element, x, y, f

	on_error, 2
	element = star()
	update_list, element, x, y, f
	return, element
end

; MERGE_LIST: merge two lists.

FUNCTION merge_list, l1, l2

	on_error, 2
	n1 = n_elements(l1)
	if  n1 eq 0  then  l = l2  else $
	begin
	   n2 = n_elements(l2)
	   l = create_list(n1 + n2)
	   l[0] = l1  &  l[n1] = l2
	endelse
	return, l
end

; APPEND_LIST: add an element to list.

FUNCTION append_list, list, element

	on_error, 2
	return, merge_list(list, element)
end

; ADD_SUBSCRIPT: add subscript s to vector of subscripts.

FUNCTION add_subscript, subscripts, s

	on_error, 2
	if  subscripts[0] lt 0  then $
	   w = s  else  w = append_elements(subscripts, s)
	return, w
end

; DELETE_ELEMENT: delete last element of list.

FUNCTION delete_element, list

	on_error, 2
	l = list  &  n = n_elements(l)
	return, l[0:n-2]
end

; EXTRACT_ELEMENTS: extract from list the elements subscripted by s.

PRO extract_elements, list, SUBSCRIPTS = s, $
					  n, x, y, f, c, sigma_x, sigma_y, sigma_f

	on_error, 2
	if  n_tags(list) eq 0  then begin
	   n = 0L  &  s = -1L  &  return
	endif
	n = n_elements(s)
	if  n eq 0  then begin
	   n = n_elements(list)  &  s = lindgen(n)	; extract all elements
	endif
	if  s[0] lt 0  then  n = 0  else begin $
	   x = list[s].x  &  sigma_x = list[s].sigma_x
	   y = list[s].y  &  sigma_y = list[s].sigma_y
	   f = list[s].f  &  sigma_f = list[s].sigma_f
	   c = list[s].c
	endelse
	return
end

; WHERE_STARS: return subscripts of elements having the field
; 'is_a_star' = true and lying into the specified range of coordinates.

FUNCTION where_stars, list, LX = lx, UX = ux, LY = ly, UY = uy, n

	on_error, 2
	if  n_tags(list) eq 0  then begin
	   n = 0L  &  return, -1L
	endif
	flag = list.is_a_star
	if  n_elements(lx) ne 0  then $
	   flag = flag and list.x ge lx and list.x le ux $
	   			   and list.y ge ly and list.y le uy
	return, where(flag and 1B, n)
end

; SUB_LIST: extract list[s].

FUNCTION sub_list, list, s

	on_error, 2
	return, list[s]
end

; EXTRACT_STARS: extract from list the sub-list of elements
; fulfilling the condition is_a_star = 'true'.

FUNCTION extract_stars, list, n

	on_error, 2
    s = where_stars(list, n)
    if  n ne 0  then  return, sub_list(list, s)  else  return, -1
end

; SORT_LIST: sort list of objects in order of decreasing intensity.

FUNCTION sort_list, list, SUBSCRIPTS = s

	on_error, 2
	if  n_tags(list) eq 0  then  return, list
	s = reverse(sort(list.f))
	return, list[s]
end

; REVERSE_CLASS: reverse the is_a_star field of the elements
; of list subscripted by s.

FUNCTION reverse_class, list, SUBSCRIPTS = s

	on_error, 2
	if  n_elements(s) eq 0  then  s = lindgen(n_elements(list))
	l = list
	l[s].is_a_star = (not l[s].is_a_star) and 1B
	return, l
end



;;; Auxiliary procedures/functions to define the program''s parameters.

; STARFINDER_FWHM: compute PSF FWHM.

FUNCTION starfinder_fwhm, psf, n_psf

	on_error, 2
	fw = fltarr(n_psf)
	for  n = 0L, n_psf - 1  do  fw[n] = fwhm(psf[*,*,n], /CUBIC, MAG = 3)
	return, fw
end

; DEFINE_CORR_BOX: define correlation box size.

FUNCTION define_corr_box, psf_fwhm

	on_error, 2
	box = round(1.5 * psf_fwhm)
	box = box + 1 - box mod 2
	return, box
end

; DEFINE_FIT_BOX: define fitting box size.

FUNCTION define_fit_box, psf_fwhm, WIDER = wider

	on_error, 2
	if  keyword_set(wider)  then  b = 2.  else  b = 1.
	box = round(define_corr_box(psf_fwhm) > 5 + b * psf_fwhm)
	box = box + 1 - box mod 2
	return, box
end

; STARFINDER_ID_PAR: define parameters to re-identify presumed stars.

FUNCTION starfinder_id_par, psf_fwhm, FOUR = four

	on_error, 2
	box = define_fit_box(psf_fwhm)
	neigh4 = keyword_set(four) and 1B
	return, {box: box, neigh4: neigh4}
end

; STARFINDER_CORR_PAR: define parameters for correlation.

FUNCTION starfinder_corr_par, psf, psf_fwhm, n_psf, CORREL_MAG = correl_mag, $
	                          _EXTRA = extra

	on_error, 2
	correlation_box = define_corr_box(psf_fwhm)
	search_box = correlation_box / 2
	search_box = search_box + 1 - search_box mod 2
	if  n_elements(correl_mag) eq 0  then  correl_mag = 1
	if  correl_mag gt 1  then  edge = 2  else  edge = 0
	temp_siz = correlation_box + 2 * edge
	template = ptrarr(n_psf, /ALLOCATE)
	if  correl_mag gt 1  then  templates = ptrarr(n_psf, /ALLOCATE) $
	else begin
	   templates = 0  &  dx = 0  &  dy = 0
	endelse
	for  n = 0L, n_psf - 1  do begin
	   temp = sub_array(psf[*,*,n], temp_siz[n])
	   if  correl_mag gt 1  then begin
	      shifted_templates, temp, correl_mag, _EXTRA = extra, EDGE = edge, $
	                         templs, dx, dy
	      temp = sub_array(temp, correlation_box[n])
	      *templates[n] = templs
	   endif
	   *template[n] = temp
	endfor
	return, {correl_mag: correl_mag, $
	         correlation_box: correlation_box, $
	         search_box: search_box, $
	         template: template, $
	         templates: templates, dx: dx, dy: dy}
end

; STARFINDER_FIT_PAR: define parameters for fitting.

FUNCTION starfinder_fit_par, psf_in, psf_fwhm, n_psf, _EXTRA = extra

	on_error, 2
	fitting_box = define_fit_box(psf_fwhm, _EXTRA = extra)
	edge = 0.5
	min_distance = 0.5 * psf_fwhm
	psf = ptrarr(n_psf, /ALLOCATE)
	fitting_psf = ptrarr(n_psf, /ALLOCATE)
	psf_max = fltarr(n_psf)
	for  n = 0L, n_psf - 1  do begin
	   *psf[n] = psf_in[*,*,n]
	   *fitting_psf[n] = sub_array(*psf[n], 2*fitting_box[n])
	   psf_max[n] = max(*psf[n])
	endfor
	return, {fitting_box: fitting_box, edge: edge, $
	         min_distance: min_distance, $
	         fitting_psf: fitting_psf, psf: psf, $
	         psf_max: psf_max, psf_fwhm: psf_fwhm}
end

; STARFINDER_DEB_PAR: define parameters for deblending.

FUNCTION starfinder_deb_par, psf, psf_fwhm, n_psf, $
	                         BIN_THRESHOLD = bin_threshold, $
	                         CUT_THRESHOLD = cut, $
	                         BIN_N_STDEV = n_std, BIN_TOLERANCE = tol

	on_error, 2
	if  n_elements(bin_threshold) eq 0  then  bin_threshold = 0.
	if  n_elements(cut) eq 0  then  cut = 0.2  &  cut = cut > 0.2 < 1
	if  n_elements(n_std) eq 0  then  n_std = 3
	if  n_elements(tol) eq 0  then  tol = 0.2  &  tol = tol > 0 < 1
	box = lonarr(n_psf)  &  area = fltarr(n_psf)
	for  n = 0L, n_psf - 1  do begin
	   box[n] = round(3 * peak_width(psf[*,*,n], REL = cut))
	   area[n] = peak_area(psf[*,*,n], REL = cut, MAG = 3)
	endfor
	return, {bin_threshold: bin_threshold, n_std: n_std, $
	         box: box, cut: cut, tol: tol, psf_area: area}
end

; STARFINDER_DEALLOC: de-allocate heap variables.

PRO starfinder_deall_corr, p

	on_error, 2
	if  n_elements(p) eq 0  then  return
	if  (ptr_valid(p.template))[0]  then  ptr_free, p.template
	if  (ptr_valid(p.templates))[0]  then  ptr_free, p.templates
	return
end

PRO starfinder_deall_fit, p

	on_error, 2
	if  n_elements(p) eq 0  then  return
	ptr_free, p.fitting_psf, p.psf
	return
end

PRO starfinder_dealloc,	fit_data, model_data, corr_par, fit_par

	on_error, 2
	if  ptr_valid(fit_data)  then  ptr_free, fit_data
	if  ptr_valid(model_data)  then  ptr_free, model_data
	starfinder_deall_corr, corr_par
	starfinder_deall_fit, fit_par
	return
end



;;; Other auxiliary procedures/functions.

; STARFINDER_BAD: find bad pixels in the sub-image [lx:ux,ly:uy].

PRO starfinder_bad, x_bad, y_bad, lx, ux, ly, uy, x_bad_here, y_bad_here

	on_error, 2
	w = where(x_bad ge lx and x_bad le ux and $
	          y_bad ge ly and y_bad le uy, n)
	if  n ne 0  then begin
	   x_bad_here = x_bad[w] - lx  &  y_bad_here = y_bad[w] - ly
	endif
	return
end

; STARFINDER_BOXES: extract boxes from image, background and image model.

PRO starfinder_boxes, image, background, stars, x, y, boxsize, $
	                  lx, ux, ly, uy, i_box, b_box, s_box, $
	                  x_bad, y_bad, x_bad_here, y_bad_here

	on_error, 2
	i_box = sub_array(image, boxsize, REFERENCE = [x, y], $
	                  LX = lx, UX = ux, LY = ly, UY = uy)
	s_box = stars[lx:ux,ly:uy]  &  b_box = background[lx:ux,ly:uy]
	if  n_elements(x_bad) ne 0 and n_elements(y_bad) ne 0  then $
	   starfinder_bad, x_bad, y_bad, lx, ux, ly, uy, x_bad_here, y_bad_here
	return
end

; STARFINDER_ID: re-identification of a presumed star.

PRO starfinder_id, image, background, stars, sv_par, id_par, $
                   min_intensity, x, y, found

	on_error, 2
	if  n_elements(sv_par) ne 0  then $
	   r = pick_region(sv_par.lx, sv_par.ux, sv_par.ly, sv_par.uy, x, y) $
	else  r = 0
	; Extract boxes
	starfinder_boxes, image, background, stars, x, y, id_par.box[r], $
	                  lx, ux, ly, uy, i_box, b_box, s_box
	; Search
	max_search, i_box - b_box - s_box, min_intensity[lx:ux,ly:uy], $
	            X0 = x - lx, Y0 = y - ly, n, x, y, $
	            /NEAREST, /MAXIMUM, FOUR = id_par.neigh4
	found = n ne 0
	if  found  then begin
	   x = x[0] + lx  &  y = y[0] + ly
	endif
	return
end

; STARFINDER_CORRELATE: correlation check.

PRO starfinder_correlate, image, background, stars, sv_par, x_bad, y_bad, $
                          corr_par, min_correlation, x, y, correl, accepted, LOGFILE = logfile

	on_error, 2
	if  n_elements(sv_par) ne 0  then $
	   r = pick_region(sv_par.lx, sv_par.ux, sv_par.ly, sv_par.uy, x, y) $
	else  r = 0
	; Extract boxes
	boxsize = corr_par.correlation_box[r] + corr_par.search_box[r] + 1
	starfinder_boxes, image, background, stars, x, y, boxsize, $
	                  lx, ux, ly, uy, i_box, b_box, s_box, x_bad, y_bad, xb, yb
	; Compute correlation
	if  corr_par.correl_mag gt 1  then begin
	   templates = *corr_par.templates[r]  &  dx = corr_par.dx  &  dy = corr_par.dy
	endif
	correlate_max, i_box - b_box - s_box, *corr_par.template[r], x - lx, y - ly, $
	               corr_par.search_box[r], X_BAD = xb, Y_BAD = yb, $
	               TEMPLATES = templates, DX = dx, DY = dy, correl, x, y
	x = x + lx  &  y = y + ly
        if keyword_set(logfile) then printf,logfile,"correlation is",correl

	accepted = correl ge min_correlation and $
	           x ge lx and x le ux and y ge ly and y le uy
	return
end

; STARFINDER_CHECK: check outcome of local fitting.

FUNCTION starfinder_check, fit_error, x_fit, y_fit, f_fit, $
	                       lx, ux, ly, uy, list, min_intensity, fit_par, r

	on_error, 2
	; Check convergence of fit, minimum acceptable value of fluxes,
	; range of positions
	good = fit_error ge 0 and $
	       min(x_fit) ge lx and max(x_fit) le ux and $
	       min(y_fit) ge ly and max(y_fit) le uy
	if  good  then begin
	   threshold = min_intensity[round(x_fit),round(y_fit)] / fit_par.psf_max[r]
	   good = min(f_fit - threshold) ge 0
	endif
	if  good  then begin
	   ; Consider the subset of stars in a neighborhood of [lx:ux,ly:uy]
	   ; and check their reciprocal distances
	   s = where_stars(LX = lx - fit_par.min_distance[r], $
	                   UX = ux + fit_par.min_distance[r], $
	                   LY = ly - fit_par.min_distance[r], $
	                   UY = uy + fit_par.min_distance[r], list, n)
	   extract_elements, list, SUBSCRIPTS = s, n, x, y, f
	   if  n gt 1  then $
	      good = min(reciprocal_distance(x, y)) ge fit_par.min_distance[r]
	endif
	return, good
end

; STARFINDER_FIT: local fitting.

PRO starfinder_fit, list, this_max, image, siz, background, stars, noise_std, $
                    sv_par, x_bad, y_bad, fit_par, fit_data, model_data, $
                    min_intensity, NO_SLANT = no_slant, $
                    RE_FITTING = re_fitting, _EXTRA = extra, star_here

	on_error, 2
	extract_elements, list, SUBSCRIPTS = this_max, n, x, y
	if  n_elements(sv_par) ne 0  then $
	   r = pick_region(sv_par.lx, sv_par.ux, sv_par.ly, sv_par.uy, x, y) $
	else  r = 0
	; Extract boxes
	starfinder_boxes, image, background,  stars, x, y, fit_par.fitting_box[r], $
	                  lx, ux, ly, uy, i_box, b_box, s_box, x_bad, y_bad, xb, yb
	if  n_elements(xb) ne 0 and n_elements(yb) ne 0  then $
	   w_bad = coord_to_subs(xb, yb, (size52(i_box, /DIM))[0])
	; Select known stars into i_box and subtract them from the image model
	s = where_stars(LX = lx + fit_par.edge, UX = ux - fit_par.edge, $
	                LY = ly + fit_par.edge, UY = uy - fit_par.edge, list, n)
	if  keyword_set(re_fitting)  then begin
	   if  n eq 0  then  s = this_max	; edge star
	   s_and_this = s
	endif else  s_and_this = add_subscript(s, this_max)
	extract_elements, list, SUBSCRIPTS = s, n, x_add, y_add, f_add, c
	if  n ne 0  then $
	   stars = image_model(x_add, y_add, -f_add, siz[0], siz[1], *fit_par.psf[r], $
	                       model_data, _EXTRA = extra, MODEL = stars)
	; Fixed contribution for local fitting
	contrib = stars[lx:ux,ly:uy]	; stars outside fitting box
	if  keyword_set(no_slant)  then begin
	   contrib = contrib + b_box  &  b_box = 0
	endif
	; Local fitting
	if  keyword_set(re_fitting)  then begin
	   x = x_add  &  y = y_add  &  f0 = f_add 
	endif else $
	   extract_elements, list, SUBSCRIPTS = s_and_this, n, x, y, f, c
	x0 = x - lx  &  y0 = y - ly
	if  n_elements(noise_std) ne 0  then  noise = noise_std[lx:ux,ly:uy]
	fitstars, i_box, FIXED = contrib, *fit_par.fitting_psf[r], $
	          PSF_DATA = fit_data, x0, y0, F0 = f0, BACKGROUND = b_box, $
	          NO_SLANT = no_slant, NOISE_STD = noise, _EXTRA = extra, $
	          BAD_DATA = w_bad, x, y, f, b, fit_error, $
	          sigma_x, sigma_y, sigma_f
	x_out = x  &  y_out = y
	compare_lists, x0, y0, x_out, y_out, x0_out, y0_out, x, y, SUBSCRIPTS_2 = w
	x = x[w] + lx  &  y = y[w] + ly  &  f = f[w]
	if  n_elements(sigma_f) ne 0  then begin
	   sigma_x = sigma_x[w]
	   sigma_y = sigma_y[w]
	   sigma_f = sigma_f[w]
	endif
	; Is the examined max a star? Assume it is, then perform checks
	temp_list = list
	update_list, temp_list, SUB = s_and_this, x, y, f, c, $
	             sigma_x, sigma_y, sigma_f, /IS_STAR
	star_here = starfinder_check(fit_error, x, y, f, lx, ux, ly, uy, $
	                             temp_list, min_intensity, fit_par, r)
	; Update list of stars, image model and background
	if  star_here  then begin
	   list = temp_list
	   x_add = x  &  y_add = y  &  f_add = f
	endif
	stars = image_model(x_add, y_add, f_add, siz[0], siz[1], *fit_par.psf[r], $
	                    model_data, _EXTRA = extra, MODEL = stars)
         
	return
end

; STARFINDER_BLEND: check the area of a presumed star to identify blends.

FUNCTION starfinder_blend, image, background, stars, noise_std, $
                           deb_par, x, y, r

	on_error, 2
	starfinder_boxes, image, background, stars, x, y, deb_par.box[r], $
	                  lx, ux, ly, uy, i_box, b_box, s_box
	ima = i_box - b_box - s_box	  ; after this, it should be positive!
	x0 = x - lx  &  y0 = y - ly
	threshold = ima[x0,y0] * deb_par.cut
	check = 1B
	if  n_elements(noise_std) ne 0  then $
	   check = threshold gt deb_par.n_std * noise_std[x,y]
	if  check  then begin
	   area = peak_area(ima, X = x0, Y = y0, MAG = 3, ABS_THRESHOLD = threshold)
	   check = relative_error(deb_par.psf_area[r], area) gt deb_par.tol
	endif
	return, check
end

; STARFINDER_DEBLEND: de-blend a crowded group of stars
; (partial or full de-blending).

PRO starfinder_deblend, list, this_max, image, siz, background, stars, $
                        noise_std, sv_par, x_bad, y_bad, id_par, fit_par, $
                        deb_par, fit_data, model_data, min_intensity, $
                        AROUND = around, _EXTRA = extra

	on_error, 2
	extract_elements, list, SUB = this_max, n, x, y, f
	x0 = round(x)  &  y0 = round(y)
	if  n_elements(sv_par) ne 0  then $
	   r = pick_region(sv_par.lx, sv_par.ux, sv_par.ly, sv_par.uy, x, y) $
	else  r = 0
	; Is the present object a blend?
	if  keyword_set(around)  then $
	   stars = temporary(stars) - image_model(x, y, f, siz[0], siz[1], $
	   				              *fit_par.psf[r], model_data, _EXTRA = extra)
	blended = starfinder_blend(image, background, stars, noise_std, $
	                           deb_par, x0, y0, r)
	if  keyword_set(around)  then $
	   stars = temporary(stars) + image_model(x, y, f, siz[0], siz[1], $
	   				              *fit_par.psf[r], model_data, _EXTRA = extra)
	if  not blended  then  return	; not a blend
	ncomp = 0L  &  found = ncomp eq 0  &  star_here = found
	if  keyword_set(around)  then  ncomp = ncomp + 1
	max_dist = 1.25 * fit_par.psf_fwhm[r]
	while  star_here  do begin
	   x = x0  &  y = y0
	   if  ncomp ne 0  then begin
	      ; Identify another component of the blend
	      starfinder_boxes, image, background, stars, x, y, deb_par.box[r], $
			                lx, ux, ly, uy, i_box, b_box, s_box
	      max_search, i_box - b_box - s_box, $
	   	              deb_par.bin_threshold * min_intensity[lx:ux,ly:uy], $
	   	              X0 = x - lx, Y0 = y - ly, CHECK_DIST = max_dist, $
	   	              /MAXIMUM, FOUR = id_par.neigh4, n, x, y
	      found = n ne 0  &  star_here = found
	      if  found  then begin
	         x = x[0] + lx  &  y = y[0] + ly
	      endif
	   endif
	   if  found  then begin
	      ; Fit the new detected component
	      if  ncomp ne 0  then begin
	         list = append_list(list, create_element(x, y, 0))
	         index = n_elements(list) - 1
	      endif else  index = this_max
	      starfinder_fit, list, index, image, siz, background, stars, $
	      		          noise_std, sv_par, x_bad, y_bad, fit_par, fit_data, $
	      		          model_data, min_intensity, _EXTRA = extra, star_here
	   endif
	   if  star_here  then  ncomp = ncomp + 1
	endwhile
	if  ncomp eq 1 and not keyword_set(around)  then begin
	   ; The object was mis-recognized as a blend: it is single
	   extract_elements, list, SUB = this_max, n, x, y, f
	   stars = temporary(stars) - image_model(x, y, f, siz[0], siz[1], $
	   				              *fit_par.psf[r], model_data, _EXTRA = extra)
	   list = reverse_class(list, SUBSCRIPT = this_max)
	endif
	return
end

; STARFINDER_ANALYZE: analyze the object list[this_max].

PRO starfinder_analyze, list, this_max, image, siz, background, stars, $
                        noise_std, sv_par, x_bad, y_bad, id_par, corr_par, $
                        fit_par, fit_data, model_data, $
                        min_intensity, min_correlation, _EXTRA = extra, LOGFILE = logfile

	on_error, 2
	extract_elements, list, SUB = this_max, n, x, y
        if keyword_set(logfile) then printf,logfile,"analysing star at",x,y

	; Is the maximum list[this_max] a feature of an already detected star?
	starfinder_id, image, background, stars, sv_par, id_par, $
	               min_intensity, x, y, check
	if  not check  then  return		    ; yes, it is

        if keyword_set(logfile) then printf,logfile,"not a feature of an already detected star"
	; Correlation check
	starfinder_correlate, image, background, stars, sv_par, x_bad, y_bad, $
	                      corr_par, min_correlation, x, y, c, check, LOGFILE = logfile
	if  not check  then  return   ; too low correlation

        if keyword_set(logfile) then printf,logfile,"correlation ok"
	; Fit
	update_list, list, SUB = this_max, x, y, 0, c
	starfinder_fit, list, this_max, image, siz, background, stars, noise_std, $
	                sv_par, x_bad, y_bad, fit_par, fit_data, model_data, $
	                min_intensity, _EXTRA = extra
	return
end

; STARFINDER_CONVERG: check convergence of positions and fluxes for Phase 3.

FUNCTION starfinder_converg, list0, list, $
		 ASTROMETRIC_TOL = a_tol, PHOTOMETRIC_TOL = ph_tol

	on_error, 2
	if  n_elements(a_tol)  eq 0  then  a_tol  = 1e-2;1e-4;0.01
	if  n_elements(ph_tol) eq 0  then  ph_tol = 1e-2;1e-4;0.01
	s = where_stars(list, n)
	if  n eq 0  then  return, n eq 0
	extract_elements, list0, SUB = s, n, x0, y0, f0
	extract_elements, list,  SUB = s, n, x,  y,  f
	check = convergence(x0, x, a_tol, /ABSOLUTE) and $
			convergence(y0, y, a_tol, /ABSOLUTE) and $
			convergence(f0, f, ph_tol)
	return, check
end


;;; The main routine.

PRO starfinder, $
	image, psf, SV_PAR = sv_par, $
	X_BAD = x_bad, Y_BAD = y_bad, $
	BACKGROUND = background, ESTIMATE_BG = estim_bg, BACK_BOX = back_box, $
	threshold, REL_THRESHOLD = rel_threshold, NOISE_STD = noise_std, $
	min_correlation, DEBLEND = deblend, DEBLOST = deblost, _EXTRA = extra, $
	N_ITER = n_iter, NO_INTERMEDIATE_ITER = no_intermediate, SILENT = silent, $
	GUIDE_X = guide_x, GUIDE_Y = guide_y, $
	SV_SIGMA_R = sv_sigma_r, SV_SIGMA_A = sv_sigma_a, $
   	x, y, fluxes, sigma_x, sigma_y, sigma_f, correlation, STARS = stars, $
        LOGFILE = logfilename

print, "Starfinder:"
print, "Estimate bg = ", estim_bg
;print, "BACK_BOX = ", back_box
print, "threshold= ", threshold, ", REL_THRESHOLD = ", rel_threshold
print, "min_correlation = ",min_correlation
print, "DEBLEND = ",deblend
;print, "DEBLOST = ",deblost
;print, "_EXTRA = ",extra
print, "N_ITER = ",n_iter
;print, "NO_INTERMEDIATE_ITER = ", no_intermediate
;print, "GUIDE_X = ",guide_x,", GUIDE_Y = ",guide_y
;print, "SV_SIGMA_R = ",sv_sigma_r,", SV_SIGMA_a = ",sv_sigma_a
;print, 'HELLO!'
;STOP

	if  not keyword_set(logfilename) then logfilename = "" $
        else print, "LOGFILE = ",logfilename

	;;catch, error
	;;if  error ne 0  then begin
        ;;    print,"starfinder encountered an error"
        ;;    print,"the details are top secret and may not leave IDL"
	;;   starfinder_dealloc, fit_data, model_data, corr_par, fit_par
	;;   return
	;;endif

	; Define some program parameters and default values
	if  n_elements(n_iter) eq 0  then  n_iter = 1
	if  size52(psf, /N_DIM) eq 3  then $
	   n_psf = (size52(psf, /DIM))[2]  else  n_psf = 1
	psf_fwhm = starfinder_fwhm(psf, n_psf)
	id_par   = starfinder_id_par(psf_fwhm, _EXTRA = extra)
	corr_par = starfinder_corr_par(psf, psf_fwhm, n_psf, _EXTRA = extra)
	fit_par  = starfinder_fit_par( psf, psf_fwhm, n_psf)
	if  keyword_set(deblend) or keyword_set(deblost)  then $
	   deb_par = starfinder_deb_par(psf, psf_fwhm, n_psf, _EXTRA = extra)
	if  n_elements(sv_par) eq 0  then begin
	   fit_data = ptr_new(/ALLOCATE)  &  model_data = ptr_new(/ALLOCATE)
	endif

	; Define background and image model
	siz = size52(image, /DIM)
        background_stars = fltarr(siz[0], siz[1])
	if  n_elements(background) eq 0  then $
	   if (estim_bg eq 0) then $
	      background = fltarr(siz[0], siz[1])  else begin
	     if  n_elements(back_box) eq 0 then $
                back_box =  corr_par.correlation_box[0] + corr_par.search_box[0] + 1
	     background = estimate_background(image, back_box, _EXTRA = extra)
           endelse
         

	if  n_elements(noise_std) ne 0  then $
	   if  n_elements(noise_std) ne n_elements(image)  then $
	      noise_std = replicate(noise_std[0], siz[0], siz[1])
	stars = fltarr(siz[0], siz[1])
	; Iterative search for suspected stars and subsequent analysis
	n_levels = n_elements(threshold)
	n_stars = 0L  &  n_presumed = 0L
        logfp = ""
        if  logfilename ne ""  then openw, logfp,logfilename,/get_lun,/append

    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;;;	Main Loop over thresholds
    ;;;
	for  n_lev = 0L, n_levels - 1  do begin

	; Update detection threshold
	threshold_n = float(threshold[n_lev])
	if  not keyword_set(silent)  then print, "STARFINDER: threshold ",threshold_n
        if  logfilename ne ""  then printf, logfp, "threshold ", threshold_n

	if  keyword_set(rel_threshold) and n_elements(noise_std) ne 0  then $
	   threshold_n = threshold_n * noise_std
	if  n_elements(threshold_n) eq 1  then $
	   threshold_n = replicate(threshold_n[0], siz[0], siz[1])

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Phase 1: find local maxima having
	; central intensity > known stars + background + threshold
        ;
	if  not keyword_set(silent)  then $
	   print, "STARFINDER: search for suspected stars"
	search_objects, image - stars, LOW_SURFACE = background, threshold_n, $
	                _EXTRA = extra, n_max, x0, y0, i0
	n_presumed = n_presumed + n_max

        if  logfilename ne ""  then printf, logfp, n_max, " suspected stars"

        ;; write out list to see what''s going on
        ;openw,unit47,'/disk-a/koehler/TrapezFinder/list_of_presumed_stars.txt',/get_lun
        ;print,"print to debug, ",n_max," stars"
        ;for n = 0, n_max-1 do begin
        ;    ;print,n
        ;    printf,unit47,n,x0[n],y0[n]
        ;endfor
        ;close,unit47

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Phase 2: analyze presumed stars with correlation and fitting,
	;		   estimating positions and fluxes.
        ;
	if  n_max ne 0  then begin
	   if  not keyword_set(silent)  then $
	      print, "STARFINDER: analysis of suspected stars"
	   list_of_max = create_list(n_max, x0, y0, i0)
	   list_of_stars = merge_list(list_of_stars, sort_list(list_of_max))

           if  logfp ne ""  then printf,logfp, "analysing star ", n_stars, " to ", n_stars - 1 + n_max
           print, "analysing star ", n_stars, " to ", n_stars - 1 + n_max
	   for  n = n_stars, n_stars - 1 + n_max  do begin
               if  logfp ne ""  then printf,logfp,"star no.",n
               if (guide_x NE "") then begin
                   print, "making local psf for star ", n
                   local_psf = make_local_psf(psf, n_psf, guide_x, guide_y, sv_sigma_r, sv_sigma_a, $
                                              list_of_stars[n].x, list_of_stars[n].y)

                                ; free memory before allocating it again
                   starfinder_deall_corr, corr_par
                   starfinder_deall_fit, fit_par

                   psf_fwhm = starfinder_fwhm( local_psf, 1)
                   id_par   = starfinder_id_par(psf_fwhm, _EXTRA = extra)
                   corr_par = starfinder_corr_par(local_psf, psf_fwhm, 1, _EXTRA = extra)
                   fit_par  = starfinder_fit_par( local_psf, psf_fwhm, 1)
               end
               starfinder_analyze, list_of_stars, n, image, siz, background, stars, $
	                          noise_std, sv_par, x_bad, y_bad, id_par, $
	                          corr_par, fit_par, fit_data, model_data, $
	                          threshold_n, min_correlation, LOGFILE = logfp, _EXTRA = extra
               flush,logfp
           endfor
	   list_of_stars = sort_list(extract_stars(list_of_stars, n_stars))

           if  logfp ne ""  then printf,logfp, "Memory before bg:", memory()
	   ; Update background estimate
           if  estim_bg  and  n_elements(back_box) ne 0  then begin
               if  not keyword_set(silent)  then $
                 print, "STARFINDER: Update background estimate"
               background = estimate_background(image - stars, back_box, _EXTRA = extra)
           endif
           if  logfp ne ""  then printf,logfp, "Memory after bg: ", memory()

	   ; Modify fitting parameters for subsequent operations
	   starfinder_deall_fit, fit_par
	   fit_par = starfinder_fit_par(psf, psf_fwhm, n_psf, /WIDER)
	   if  ptr_valid(fit_data)  then  ptr_free, fit_data
	endif	; n_max ne 0

	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Phase 2b: de-blend detected objects.

	if  keyword_set(deblend) and n_lev eq n_levels - 1 and n_stars ne 0  then begin
	   if  not keyword_set(silent)  then $
	      print, "STARFINDER: deblending of detected stars"
	   ; Check each detected star: is it a blend?
	   for  n = 0L, n_stars - 1  do $
	      starfinder_deblend, list_of_stars, n, image, siz, background, stars, $
	                          noise_std, sv_par, x_bad, y_bad, id_par, $
	                          fit_par, deb_par, fit_data, model_data, $
	                          threshold_n, _EXTRA = extra, /AROUND
	   list_of_stars = sort_list(extract_stars(list_of_stars, n_stars))
	   ; Update background estimate
	   if  estim_bg  and  n_elements(back_box) ne 0  then $
	      background = estimate_background(image - stars, back_box, _EXTRA = extra)
	endif

	; Phase 2c: recover lost objects to search for blends.
	if  keyword_set(deblost) and n_lev eq n_levels - 1 and n_stars ne 0  then begin
	   if  not keyword_set(silent)  then $
	      print, "STARFINDER: search for blends among lost objects"
	   search_objects, image - stars, LOW_SURFACE = background, threshold_n, $
	                   _EXTRA = extra, n_max, x0, y0, i0
	   if  n_max ne 0  then begin
	      list_of_max = create_list(n_max, x0, y0, i0)
	      list_of_stars = merge_list(list_of_stars, sort_list(list_of_max))
	      for  n = n_stars, n_stars - 1 + n_max  do $
	         starfinder_deblend, list_of_stars, n, image, siz, background, stars, $
	                             noise_std, sv_par, x_bad, y_bad, id_par, fit_par, $
	                             deb_par, fit_data, model_data, threshold_n, $
	                             _EXTRA = extra
	      list_of_stars = sort_list(extract_stars(list_of_stars, n_stars))
	      ; Update background estimate
	      if  estim_bg  and  n_elements(back_box) ne 0  then $
	         background = estimate_background(image - stars, back_box, _EXTRA = extra)
	   endif
	endif

	; Phase 3: re-determination of positions and fluxes by iterative
	;		   fitting of detected stars.
	if  n_lev eq n_levels - 1  then  maxit = n_iter  else $
	if  keyword_set(no_intermediate)  then  maxit = 0  else  maxit = 1
	if  n_stars ne 0  then  list0 = list_of_stars
	iter = 0L  &  converging = n_stars eq 0
	while  iter lt maxit and not converging  do begin
	   if  not keyword_set(silent)  then $
	      if  n_lev lt n_levels - 1  then $
	         print, "STARFINDER: intermediate re-fitting"  else $
	         print, "STARFINDER: final re-fitting: iteration", iter + 1
           for  n = 0L, n_stars - 1  do begin
               if (guide_x NE "") then begin
                   print, "refit: making local psf for star ", n
                   local_psf = make_local_psf(psf, n_psf, guide_x, guide_y, sv_sigma_r, sv_sigma_a, $
                                              list_of_stars[n].x, list_of_stars[n].y)

		; free memory before allocating it again
                   starfinder_deall_fit, fit_par

                   psf_fwhm = starfinder_fwhm( local_psf, 1)
                   fit_par  = starfinder_fit_par( local_psf, psf_fwhm, 1)
               end
               starfinder_fit, list_of_stars, n, image, siz, background, stars, $
	                      noise_std, sv_par, x_bad, y_bad, fit_par, fit_data, $
	                      model_data, threshold_n, /RE_FITTING, _EXTRA = extra
           endfor
	   if  maxit gt 1  then $
	      converging = starfinder_converg(list0, list_of_stars, _EXTRA = extra)
	   iter = iter + 1  &  list0 = list_of_stars
	endwhile
	starfinder_deall_fit, fit_par
	fit_par = starfinder_fit_par(psf, psf_fwhm, n_psf)
	if  ptr_valid(fit_data)  then  ptr_free, fit_data

	endfor
    ;;; end of cycle on threshold levels
        if  logfp ne ""  then close, logfp


	; De-allocate pointer heap variables
	starfinder_dealloc, fit_data, model_data, corr_par, fit_par

	; Save results
	if  n_stars ne 0  then begin
	   list_of_stars = sort_list(extract_stars(list_of_stars, n_stars))
	   extract_elements, list_of_stars, n_stars, $
	                     x, y, fluxes, correlation, sigma_x, sigma_y, sigma_f
	endif
	if  not keyword_set(silent)  then begin
	   print, "STARFINDER", n_presumed,   "  : presumed stars"
	   print, "STARFINDER", n_stars, "  : detected stars"
	endif
	return
end
