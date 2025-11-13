import settings;
//settings.prc = false;
settings.outformat="png";
settings.render = 16;

size(450,450);


label("$RA$", (0,0));


//outputs
picture py_box;
label(py_box, "$PY[c={\rm commodities}]$", (0,0));
label(py_box, "${\rm Household\_Supply}[c,s]$", (0,0), 2*S);
pair PY = (-8,5);
draw( (0,0)--PY, Arrow, Margin(5,12));
add(py_box, PY);

picture PFX_box;
label(PFX_box, "$PFX$", (0,0));
label(PFX_box, "${\rm Balance\_of\_Payments}$", (0,0), 2*S);
pair PFX_out = (-4,8);
draw( (0, 0)--PFX_out, Arrow, Margin(5,8));
add(PFX_box, PFX_out);

picture PA_out;
label(PA_out, "$PA[c={\rm commodities}]$", (0,0));
label(PA_out, "$-{\rm Other\_Final\_Demand}$", (0,0), 2*S);
pair PA = (4,8);
draw( (0,0) -- PA, Arrow, Margin(5,8) );
add(PA_out, PA);

picture PVA_box;
label(PVA_box, "$PVA[va={\rm value\_added}]$", (0,0));
label(PVA_box, "$\displaystyle \sum_{s\in {\rm sectors}} {\rm Value_\_Added}[va,s]$", (0,0), 2*S);
pair PVA = (8,5);
draw((0,0) -- PVA, Arrow, Margin(5,20) );
add(PVA_box, PVA);


//inputs

picture pa_in;
label(pa_in, "$PA[c = {\rm commodities}]$, ${\rm Personal\_Consumption}[c,s]$", (0,0));
pair PA_in = (0,-5);
draw( PA_in -- (0, 0), Arrow, Margin(5,5) );
add(pa_in, PA_in);