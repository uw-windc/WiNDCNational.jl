import settings;
//settings.prc = false;
settings.outformat="png";
settings.render = 16;

size(450,200);


label("$MS[m=\rm{margins}]$", (0,0));
label("$t=0$", (0,0), 1.8*N);
label("$s=0$", (0,0), 1.8*S);


//outputs
picture pm_box;

label(pm_box, "$PM[m]$, $\displaystyle\sum_{c\in{\rm commodities}} {\rm Margin\_Supply}[c,m]$", (0,0));

pair PM = (0,3);
draw( (0,0)--PM, Arrow, Margin(5,8) );
add(pm_box, PM);


//inputs

picture py_box;
label(py_box, "$PY[c = {\rm commodities}]$, ${\rm Margin\_Supply}[c,m]$", (0,0));

pair PY = (0,-3);

draw( PY -- (0, 0), Arrow, Margin(5,8) );
add(py_box, PY);

