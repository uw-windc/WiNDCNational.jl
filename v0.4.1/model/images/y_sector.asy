import settings;
//settings.prc = false;
settings.outformat="png";
settings.render = 16;

size(450,450);


label("$Y[s=\rm{sectors}]$", (0,0));
label("$t=0$", (0,0), 1.8*N);
label("$s=0$", (0,0), 1.8*S);


//outputs
picture py_box;

label(py_box, "$PY[c={\rm commodities}]$, ${\rm Intermediate\_Supply}[c,s]$", (0,0));
label(py_box, "$RA \Rightarrow {\rm Output\_Tax}[s]$", (0,0), 2*S);

pair PY = (0,5);
draw( (0,0)--PY, Arrow, Margin(5,8) );
add(py_box, PY);


//inputs

picture pa_box;
label(pa_box, "$PA[c = {\rm commodities}]$, ${\rm Intermediate\_Demand}[c,s]$", (0,0));

picture va_box;
label(va_box, "$PVA[va={\rm value\_added}]$, ${\rm Value\_Added}[va,s]$", (0,0));

pair PA = (-5,-5);
pair VA_nest = (5,-5);
pair VA = (5,-10);

draw( PA -- (0, 0), Arrow, Margin(5,8) );
add(pa_box, PA);

draw( VA_nest -- (0,0), Arrow, Margin(2,8) );
label("$va = 1$", VA_nest);

draw( VA -- VA_nest, Arrow, Margin(5,2) );
add(va_box, VA);