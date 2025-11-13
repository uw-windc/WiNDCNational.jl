import settings;
//settings.prc = false;
settings.outformat="png";
settings.render = 16;

size(450,450);


label("$A[c=\rm{commodities}]$", (0,0));
label("$t=2$", (0,0), 1.8*N);
label("$s=0$", (0,0), 1.8*S);


//outputs
picture pa_box;

label(pa_box, "$PA[c]$, ${\rm Armington\_Supply}[c]$", (0,0));
label(pa_box, "$RA \Rightarrow {\rm Absorption\_Tax}[c]$", (0,0), 2*S);
label(pa_box, "ref\_price = $1-{\rm initial\_absorption\_tax}$", (0,0), 6*S);

pair PA = (5,5);
draw( (0,0)--PA, Arrow, Margin(8,13) );
add(pa_box, PA);


picture pfx_out;

label(pfx_out, "$PFX$, ${\rm Export}[c]$", (0,0));
pair PFX = (-5,5);
draw( (0, 0)--PFX, Arrow, Margin(8,4));
add(pfx_out, PFX);



//inputs

picture pm_box;
label(pm_box, "$PM[m = {\rm margins}]$, ${\rm Margin\_Demand}[c,s]$", (0,0));

picture pfx_in;
label(pfx_in, "$PFX$, ${\rm Import}[c]$", (0,0));
label(pfx_in, "$RA\Rightarrow {\rm Import\_Tariff}[c]$", (0,0), 2*S);
label(pfx_in, "ref\_price = $1+{\rm initial\_import\_tariff}$", (0,0), 6*S);

picture PY_box; 
label(PY_box, "$PY[c]$, ${\rm Gross\_Output}[c]$", (0,0));


pair PM = (-5, -5);
pair DM_nest = (5, -5);
pair PY = (9, -10);
pair PFX = (1, -10);

draw( PM -- (0, 0), Arrow, Margin(5,8) );
add(pm_box, PM);

draw( DM_nest -- (0,0), Arrow, Margin(2,8) );
label("$dm = 2$", DM_nest);

draw( PFX -- DM_nest, Arrow, Margin(5,2) );
add(pfx_in, PFX);

draw( PY -- DM_nest, Arrow, Margin(5,2) );
add(PY_box, PY);