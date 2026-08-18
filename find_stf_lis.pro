FUNCTION psf_clean
END
FUNCTION sort_list
END
FUNCTION starlist
END
FUNCTION merge_list
END
FUNCTION extract_stars
END
FUNCTION starfinder_id_par
END
FUNCTION starfinder_fit_par
END
FUNCTION starfinder_fwhm
END
FUNCTION starfinder_corr_par
END
FUNCTION starfinder_converg
END
FUNCTION starfinder_deb_par
END

function find_stf_lis_input_list, input
    ; Count the number of stars to deal with
    numStars= numlines(input)

    ; If something unexpected happens get out
    if (numStars lt 1) then begin
        print, "****** 0 stars in the input list. SOMETHING WRONG. ******"
        retall
    endif
 
    ; Create variables to store stuff
    inName = strarr(numStars)
    inMag = fltarr(numStars)
    inDate = fltarr(numStars)
    inX = fltarr(numStars)
    inY = fltarr(numStars)
    inCorr = fltarr(numStars)

    ;Read in the File
    openr, u, input, /get_lun

    ; Loop through the file and read in all the info
    for i=0, numStars-1 do begin
        temp = ''
        readf, u, temp
        line = strsplit(temp, /EXTRACT)
        numstrings = N_ELEMENTS(line)
        ; Two possible formats in reading, with or without error
        ; and with or without the number at the end
        
        ; These are the same in either case
        inName[i]= string(line[0])
        inMag[i] = float(line[1])
        inDate[i] = float(line[2])
        inX[i] = float(line[3])
        inY[i] = float(line[4])
        
        ; Depending on if the file includes errors or not
        ; pick out the correct correlation values
        if (numstrings eq 11 or numstrings eq 12) then begin
            inCorr[i] = float(line[8]) 
        endif else if (numstrings eq 10 or numstrings eq 9 ) then begin
            inCorr[i] = float(line[6])
        endif else begin
            ; If the input file is an unrecognizable format, stop
            ; if (numstrings lt 10 or numstrings gt 12) then begin
            print, "Input file is an unrecognized format - retalling."
            retall
        endelse

    endfor
    close, u & free_lun, u

    ; Sort by Magnitude BUT keep the first star at the top of the list
    order = sort(inMag[1:*])
    order = [0, order]

    inStars = REPLICATE( { name: '', $
            mag: 0.0, $
            x: 0.0, $
            y: 0.0, $
            c: 0.0, $
            year: 0.0, $
            i0: 0.0 $
          }, N_ELEMENTS(inX))
    instars.name = inName[order]
    instars.x = inX[order]
    instars.y = inY[order]
    instars.c = inCorr[order]
    instars.year = inDate[order]
    instars.mag = inMag[order]

    return, instars
 end

;+
; NAME:
;     find_stf_lis, imageRoot, imageDir, corr, input, $
;                  psfFile=psfFile, backFile=backFile, outDir=outDir, $
;                  deblend=deblend, deblost=deblost, isSpeckle=isSpeckle, $
;                  noSave=noSave, nosig=nosig, $
;                  outBack=outBack, inBack=inBack, $
;                  /trimframes, /fixPos, /outStars
;
; PURPOSE:
;    Run starfinder using an input list of stars. Stars outside of
;    this list cannot be found, but not all the stars in the input
;    list may be re-found with above the corrleation threshold.
; 
;    Beware that this version of starfinder may produce results that
;    are biased to the input positions and photometry. This has not
;    been quantified.
; 
;    DEBLEND is not implemented.
;
; INPUTS:
;    imageRoot -- The image and output file root name Ex: mag95jul. The
;                 resulting output file will be mag95jun_0.7_inp.lis
;                 for example.
;    imageDir -- The input directory where the image, PSF, and
;                background files reside.
;    corr -- Correlation values. Starfinder will be run
;            at the correlation value specified.
;    input -- The input list of stars. Starfinder will ONLY find
;             sources that are at the positions of those stars in the
;             input list. 
;
; OPTIONAL INPUTS:
;    psfFile -- Directory and file name of the PSF. If this isn't set
;               then by default the PSF will be
;               imageDir + imageRoot + '_psf.fits'.
;    backFile -- Directory and file name of the background image. This
;                is used if /inBack is specified as the input file and
;                if /outBack is specified, the output file as well. If
;                both /inBack and /outBack are specified, the
;                previously used background will be overwritten.
;    deblend -- Default value is to turn deblending off. (untested)
;    outDir  -- Directory for file output. (include trailing /)
;    /isSpeckle -- Just tells where to get the *.sig file (either in
;                 FITS format for AO data or as a *.sig file for
;                 speckle).
;    /inBack -- Use an input background file rather than calcing from
;               scratch. The input file is either specified using the
;               backFile variable or is retrieved from 
;               imageDir + imageRoot + '_back.fits'.
;    /outBack -- Save new background to a file. The output file 
;               is either specified using the
;               backFile variable or is retrieved from 
;               imageDir + imageRoot + '_back.fits'. WARNING:
;               Backgrounds can easily be overwritten!!!
;     /trimframes -- Use this to trim the edges of stars without
;                    enough frames in them. Uses a flat drop flat 
;                    algorithm to keep high correlation sources
;                    with less frames than low correlation sources 
;                    at the same frames
;    /outStars - Output the detected stars map
;               imageDir + imageRoot + '_stars.fits'.
;    /fixPos -- Input stars are forced to be detected precisely where
;               they are input. In this case, only flux and background
;               are allowed to vary.
;
; EXAMPLE:
;    find_stf_lis, 'mag95jun', '/net/kefa/data/1/jlu/gc/95jun/combo/',
;                  0.5, 'input_fs.lis', /isSpeckle
;    
;
; MODIFICATION HISTORY:
;    04/20/2005 - Jessica Lu adapted from Seth Hornstein's find_mwsaa.
;    05/25/2005 - Added options for no saved Session. S. Hornstein
;    05/26/2005 - Added option to specify input list has errors. S.Hornstein
;    05/06/2005 - Removed saveFile and added explicit psfFile and
;                 backFile keywords. (J. Lu)
;    07/19/2005 - Changed input file reading to be able to deal with
;                 two different kinds of input lists automatically and
;                 a mixed file of the two (errors and no errors) 
;                 Removed /hasError flag (M. Rafelski)
;    09/19/2005 - Added trimframes (M. Rafelski)
;    09/20/2005 - Added /fixPos and /outStars. (Hornstein)
;    08/14/2006 - turned on deblend/deblost option (not tested yet) (Hornstein)
;    08/14/2006 - Fixed instars structure replication error. Previous
;                 runs MAY be missing an occasional star or two.
;-

pro find_stf_lis, imageRoot, imageDir, corr, input, $
                  psfFile=psfFile, backFile=backFile, outDir=outDir, $
                  deblend=deblend, deblost=deblost, isSpeckle=isSpeckle, $
                  outBack=outBack, inBack=inBack, $
                  trimframes=trimframes, fixPos=fixPos, outStars=outStars, $
                  cooStar=cooStar, starlist=starlist

    IF n_params(0) eq 0 THEN BEGIN
       print,"Usage: imageRoot, imageDir, corr, input, $"
       print,"       psfFile=psfFile, backFile=backFile, outDir=outDir, $"
       print,"       /deblend, /deblost,/isSpeckle, $"
       print,"       /outBack, /inBack, /trimalign, /fixPos, /outStars"
       RETALL
    ENDIF

    RESOLVE_ROUTINE, 'starfinder', /compile_full_file
    RESOLVE_ROUTINE, 'psf_extract', /compile_full_file

    ; Construct root file name
    inRoot = imageDir + imageRoot

    if not keyword_set(psfFile) then psfFile = inRoot + '_psf'
    if not keyword_set(backFile) then backFile = inRoot + '_back'
    if not keyword_set(outDir) then outDir=''
    if not keyword_set(deblend) then deblend=0
    if not keyword_set(deblost) then deblost=0
    if not keyword_set(isSpeckle) then isSpeckle = 0
    if not keyword_set(outBack) then outBack = 0
    if not keyword_set(inBack) then inBack = 0
    if not keyword_set(trimalign) then trimalign = 0
    if not keyword_set(fixPos) then fixPos = 0
    if not keyword_set(outStars) then outStars = 0
    if not keyword_set(cooStar) then cooStar = 'irs16C'
    if not keyword_set(starlist) then starlist = '/u/ghezgroup/code/idl/gc/starfinder/psfstars/psf_central.dat'

    print, 'FIND_STF_LIS: Starting at ', SYSTIME()

    ; Here are all the file names.
    imageFile = inRoot + '.fits'
    maxFile = inRoot + '.max'
    psfFile = psfFile + '.fits'
    backFile = backFile + '.fits'
    starsFile = inRoot + '_stars.fits'

    ; Print out the files we are working on.
    print, format='(%"FIND_STF_LIS: Image      %s")', imageFile
    print, format='(%"FIND_STF_LIS: PSF        %s")', psfFile
    print, format='(%"FIND_STF_LIS: Background %s")', backFile

    ; If this isn't Speckle, then the sig file must be a FITS file
    ; since it most likely won't be 1024 x 1024
    sigFile = inRoot + '_sig.fits'
    if (exist(sigFile) EQ 0) then sigFile = inRoot + '_wgt.fits'
    if (exist(sigFile) EQ 0) then sigFile = inRoot + '.sig'
    if (exist(sigFile) EQ 0) then sigFile = 'single'

    ; Setup Output Information    
    file = outDir + imageRoot + '_' + strmid(strtrim(corr,1),0,3) 
    if (deblend EQ 1) then file = file + 'd'
    if (fixPos EQ 1) then file = file + 'f'

    ;----------
    ; Load image file
    ;----------
    fits_read, imageFile, image, hdr

    ; All AO data needs to deal with saturation and non-linearity. 
    ; Only speckle data doesn't deal with it. If there is no *.max 
    ; then just set the maxThreshold above the maximum pixel value
    ; in the image.
    if exist(maxFile) then begin
       openr, _max, maxFile, /get_lun
       readf, _max, maxThreshold
       free_lun, _max
    endif else begin
       print, format='(%"FIND_STF_LIS: Assuming no saturation issues")'
       maxThreshold = max(image) + 1.0
    endelse

    ;----------
    ; Load Input Starlist
    ;----------
    inStars = find_stf_lis_input_list(input)

    extra = { CORREL_MAG: 2L, $
              INTERP_TYPE: 'I', $
              PRE_SMOOTH: 1, $
              SKY_MEDIAN: 1, $
              FORCE: 1}
    
    ;------------------------------
    ;
    ; STARFINDER SETUP
    ;   -- load all the relevant files
    ;   -- setup needed variables (PSF, background, noise)
    ; 
    ;------------------------------

    ; PSF
    fits_read, psfFile, psf, psfHdr
    
    ; Properties of the image
    theta = get_pa(hdr)           ; good for HST, NIRC2, speckle, OSIRIS, etc.
    scale = get_scale(hdr)        ; arcsec per pixel
    filter = get_filter_name(hdr) ; should match in psfstars/psf_central.dat
    print, format='(%"FIND_STF_LIS: PA = %d, FILTER = %s, SCALE = %5.3f")', $
           theta, filter, scale



    ;------------------------------
    ;
    ; Calculate noise and size of image
    ;
    ;------------------------------
    gauss_noise_std, image, mode, std, PATCH=3, NTERMS_FIT=6
    siz = size52(image, /dim)

    ; Set PSF FWHM and background box size.
    psf_fwhm = (starfinder_fwhm(psf, 1))[0]
    back_box = round(9.0*psf_fwhm)

    ; Load or calculate background
    if (inBack EQ 1) then begin
        fits_read, backFile ,background
    endif else begin
        background = estimate_background(image, back_box, _EXTRA = extra)
    endelse
    
    ; Set some parameters
    threshold = [1.]
    min_correlation = corr
    threshold_n = 1 * std
    correl_mag = 2

    ; Use the first star as the reference star (e.g. 16C or user specified)
    x16c = inStars[0].x
    y16c = inStars[0].y
    m16c = inStars[0].mag
    year = inStars[0].year

    ; REPAIR saturated sources
    ; Most of this code is hacked together from pieces of 
    ; psf_extract.
    if not isSpeckle and exist(maxFile) then begin
        stf_psf_positions, image, x16c, y16c, year, scale, theta, $
                           xPsf, yPsf, xSec, ySec, $
                           filter=filter, /saturated, $
                           maxThresh=maxThreshold, refName=cooStar, $
                           starlist=starlist
        
        ; Find only saturated sources
        ;;Modified by S. Hornstein to find saturated sources where the
        ;;core has rolled over
        n_satur=0
        peaks = image[xPsf, yPsf]

        for i=0L, n_elements(xPsf)-1 do $
          peaks[i]=max(image[xPsf[i]-2:xPsf[i]+2,yPsf[i]-2:yPsf[i]+2])
   
        w = where(peaks lt maxThreshold, count, $
                  complement = v, ncomplement = n_satur)

        if (n_satur GT 0) then begin
           print, 'FIND_STF_LIST: Saturation beyond max threshold:', maxThreshold
           print, 'number saturated: ', n_satur
           x_sat = xPsf[v]  &  y_sat = yPsf[v]
           psf_fwhm = fwhm(psf, MAG = 3, /CUBIC)
           
                                ; Fit and subtract secondary sources
            fitbox = round(2 * psf_fwhm) ; fitting box
            clean_image = psf_clean(image, psf, xSec, ySec, $
                                    fitbox, _EXTRA = extra)
            

            repair_saturated, image, clean_image, background, psf, $
                              psf_fwhm, x_sat, y_sat, maxThreshold, $
                              _EXTRA = extra
         endif
    endif

    xPsf = [x16c]
    yPsf = [y16c]

    ;--------------------
    ;   Clean up starlist and calculate fluxes.
    ;--------------------
    ; Fix bad magnitudes (they were wrong anyhow)
    idx = where(inStars.mag GT 21, cnt)
    if cnt GT 0 then inStars[idx].mag = 21.0

    ; Convert magnitudes to fluxes using coordinates for
    ; the first star in the list and scaling from that. 
    ; Save the coordinates for later use. 
    ; Convert all magnitudes to intensities
    f0 = max(image[x16c-4:x16c+4, y16c-4:y16c+4])
    inStars.i0 = (10^( -1 * (inStars.mag - m16c) / 2.5 )) * f0

    ; We need to trim out all the sources that are not 
    ; within the size of this image. Lets also trim out all sources
    ; are just zeros in this image.
    good = where(inStars.x GT 0+5 AND inStars.x LT siz[0]-5-1 AND $
                 inStars.y GT 0+5 AND inStars.y LT siz[1]-5-1, goodCnt)
    inStars=inStars[good]

    ;--------------------
    ; PERFORMANCE BOOST:
    ; Loop through and get rid of those with zeros
    ;--------------------
    boxSum = fltarr(n_elements(good))
    for i=0, n_elements(good)-1 do begin
        xl = round(inStars[i].x-2)
        xu = round(inStars[i].x+2)
        yl = round(inStars[i].y-2)
        yu = round(inStars[i].y+2)
        
        boxSum[i] = total(image[xl:xu,yl:yu])
    endfor

    good = where(boxSum NE 0, goodCnt)
    inStars=inStars[good]

    ; Count up the number of stars:
    n_max = goodCnt
    fmt = '(%"Candidates %d out of %d (16C @ %3d %3d with '
    fmt = fmt + 'mag=%4.1f flux=%8.1f)")'
    print, format=fmt, n_max, n_elements(inX), x16c, y16c, m16c, f0
    
    x = inStars.x
    y = inStars.y
    f = inStars.i0

    starfinder, image, psf, $
                background = background, $
                BACK_BOX = back_box, /SKY_MEDIAN, $
                threshold, REL_THRESHOLD=1, /PRE_SMOOTH, $
                NOISE_STD = std, min_correlation, $
                CORREL_MAG = correl_mag, $
                DEBLEND = deblend, DEBLOST = deblost, N_ITER = niter, $
                x, y, f, sx, sy, sf, c, STARS = stars, $
                FORCE = 1, FIX_POS = fixPos
 

   ; --------------------
    ; Now write output
    ;--------------------
    out = [transpose(x), $
           transpose(y), $
           transpose(f), $
           transpose(sx), $
           transpose(sy), $
           transpose(sf), $
           transpose(c)]

    if (keyword_set(outBack)) then begin
        fits_write, backFile, background, hdr
    endif
    if keyword_set(outStars) then begin
        fits_write, starsFile, stars, hdr
    endif

    ;---------------
    ; Find 16C and make it the first star in the list
    ;---------------
    d = distance(x16c,y16c,x,y)
    w = where(d le 10.0)

    ; Sort based on flux
    fidx = reverse(sort(f[w]))
    w = w[fidx[0]] 

    ; Swap so that 16C is at the top.
    swap1 = out[*,0] & swap2 = out[*,w[0]]
    out[*,w[0]] = swap1 & out[*,0] = swap2

    ;----------
    ; Write output file
    ;----------
    txtfile = file + '_inp.txt'
    OPENW, lun, txtfile, /GET_LUN
    PRINTF, lun, out  &  free_lun, lun

    txt2lis_counts, file+'_inp', sigFile, year, firstName=cooStar

    ; trimframes alogrithm
                                ; NOTE: I CHANGED THIS TO 60 PERCENT
                                ; FOR PHOTOMETRY... YOU SHOULD USE 15%!!!
    if (keyword_set(trimframes)) then begin
        trimframes, file+'_inp.lis'
    endif
end
