import settings;
//settings.prc = false;
settings.outformat="png";
settings.render = 16;

size(500,500);




real width = 8;
real table_width = 100;

path value_added = (0,-width)--(0,-7*width)--(table_width,-7*width)--(table_width,-width)--cycle;

draw(value_added);

label("Labor\_Demand", (50, -1.75*width));
draw((0, -2.5*width)--(100,-2.5*width), dashed);

label("Capital\_Demand", (50, -(4+2.5)/2*width));
draw((0, -4*width)--(100,-4*width), dashed);

label("Sector\_Subsidy", (50, -(4+5.5)/2*width));
draw((0, -5.5*width)--(100,-5.5*width), dashed);

//label("Value Added", (50,-4*width/2));
label("Other\_Tax", (50,-(5.5+7)/2*width));



path intermediate_demand = (0,0) -- (0,10*width) -- (table_width,10*width) -- (table_width,0) -- cycle;

label(rotate(90)*"commoditity", (0, 5*width), align = W);
label("sector", (table_width/2, 10*width), align = N);


draw(intermediate_demand);
label("Intermediate\_Demand", (50,65));

real start = table_width + width;
table_width = 5.5*width;

path final_demand = (start, 0) -- (start, 10*width) -- (start + table_width, 10*width) -- (start + table_width, 0) -- cycle;
draw(final_demand);

label(rotate(90)*"Investment\_Final\_Demand", (start + table_width/4 - .5*width, 5*width), fontsize(8));

draw((start + table_width/4, 0)--(start + table_width/4, 10*width), dashed);
label(rotate(90)*"Government\_Final\_Demand", (start + 2*table_width/4 - .5*width, 5*width), fontsize(8));


draw((start + 2*table_width/4, 0)--(start + 2*table_width/4, 10*width), dashed);
label(rotate(90)*"Personal\_Consumption", (start + 3*table_width/4 - .5*width, 5*width), fontsize(8));


draw((start + 3*table_width/4, 0)--(start + 3*table_width/4, 10*width), dashed);
label(rotate(90)*"Export", (start + 4*table_width/4 - .5*width, 5*width));

label("Use", ((start+table_width)/2, 12*width), fontsize(20));







real start = start + table_width + 5*width;
table_width = 100;

label("Supply", ((start + start+table_width+width + 1.5*6*width)/2, 12*width), fontsize(20));

label(rotate(90)*"commoditity", (start, 5*width), align = W);
label("sectors", (start + table_width/2, 10*width), align = N);

path intermediate_supply = (start, 0) -- (start, 10*width) -- (start + table_width, 10*width) -- (start + table_width, 0) -- cycle;
draw(intermediate_supply);

label("Intermediate\_Supply", (start + table_width/2, 65));

real start = start + table_width + width;
table_width = 1.5*7*width;

draw((start, 0)--(start, 10*width)--(start + table_width, 10*width)--(start + table_width, 0)--cycle);

for(int i = 1; i < 7; ++i) {
  draw((start + 1.5*i*width, 0)--(start + 1.5*i*width, 10*width), dashed);
}

string[] labels = {"CIF/FOB","Import", "Transport", "Trade", "Duty", "Tax", "Subsidy"};

for(string p : labels) {
  label(rotate(90)*p, (start + 1.5*width/2, 5*width));
  start = start + 1.5*width;
}

