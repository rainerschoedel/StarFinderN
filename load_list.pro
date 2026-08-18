;
; load_list
;
; Created:	Wed May  2 13:10:21 2001 by koehler@hex.ucsd.edu
; Last Change:	y
;
; PURPOSE:
;	read a list of stars as written by xstarfinder
;
; CALLING SEQUENCE:
;	load_list, filename, x, y, flux, sx, sy, sf, correl
;
; INPUT:
;	filename:	name of file to read
;
; OUTPUT:
;	x:		vector of x-coordinates
;	y:		vector of y-coordinates
;	flux:		vector of stellar fluxes
;	sx, sy, sf:	vectors of errors on positions and fluxes
;	Correlation:	Vector of correlation coefficients for accepted stars.
;			Stars in crowded groups detected with the de-blending
;			procedure have a correlation coefficient of -1.
;
pro load_list, filename, x, y, flux, sx, sy, sf, correl

	data = transpose( read_float_data(filename, 7))
	x    = data(*,0)
	y    = data(*,1)
	flux = data(*,2)
	sx   = data(*,3)
	sy   = data(*,4)
	sf   = data(*,5)
	correl= data(*,6)
end
