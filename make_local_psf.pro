;; make_local_psf: create psf for star at given position
;;
;; Created:	Mon Mar 26 18:46:46 2001
;; Last Change: Wed May 16 15:28:18 2001
;;

FUNCTION make_local_psf, psf, n_psf, guide_x, guide_y, sigma_r, sigma_a, x, y

	; Error messages are great (RK)
	on_error, 0

        if (guide_x EQ "") then begin
            print,"make_local_psf: no guide star position given!"
            return, psf
        end

        print,"          sv_r = ", sigma_r, "  sv_a = ", sigma_a

        x = x - guide_x
        y = y - guide_y
        if x eq 0 and y eq 0 then return, psf[*,*,0L]
        r = sqrt(x*x + y*y)
        ph= atan(y,x)
        ;print, "local psf at dx=", x, ", dy =", y
        ;print, "              r=", r, ", phi=",ph

        sizes = size52(psf)
        ;print, "psf sizes are", sizes

        ; sigma_x/y are in coordinate system of the elliptical gaussian
        sigma_x = r * sigma_r  ;Trapez: 0.0085
        sigma_y = r * sigma_a  ;Trapez: 0.0050
        sq_x = sigma_x * sigma_x
        sq_y = sigma_y * sigma_y

        ;;size_x = ceil(sigma_x * 8.) < (sizes[1]-2.)	;; convol-kernel must be *smaller* than array
        size_x = ceil(sigma_x * 8.)
        size_y = ceil(sigma_y * 8.)

        if size_x lt 2 and size_y lt 2 then return, psf[*,*,0L]

        xarr = (findgen(size_x) - size_x/2.) # make_array(size_y, VALUE=1)
        yarr = make_array(size_x, VALUE=1) # (findgen(size_y) - size_y/2.)

        xg =  xarr * cos(ph) + yarr * sin(ph)
        yg = -xarr * sin(ph) + yarr * cos(ph)

        gauss = exp( -0.5 * ((xg * xg / sq_x) + (yg * yg / sq_y))) / (2.*!Pi*sigma_x*sigma_y)
        res = convol( extend_array(psf[*,*,0L], sizes[1]+size_x, sizes[2]+size_y), gauss)
        ;;
        ;; /EDGE_TRUNCATE would not truncate the array, but repeat the
        ;; values at the edge.  That's what we need, but it takes ages

        offs = [size_x, size_y]
        offs = (offs + offs mod 2) / 2	; that's what extend_array uses
        ;print, "sizes: ", size52(res)
        ;print, "offset: ", offs

        res  = res[ offs[0]:offs[0]+sizes[1]-1, offs[1]:offs[1]+sizes[2]-1 ]

        print, "          Size is ",size_x," *",size_y,", Norm is ", total(res)
	;writefits, "/disk-a/koehler/local_psf.fits", res

        return, res
end
