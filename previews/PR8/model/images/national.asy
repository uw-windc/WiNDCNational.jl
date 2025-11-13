import settings;
//settings.prc = false;
settings.outformat="png";
settings.render = 16;

real image_size = 450;
real Scale = .5;




include "y_sector.asy";
picture y_sector = currentpicture;
currentpicture = new picture;

include "A_sector.asy";
picture a_sector = currentpicture;
currentpicture = new picture;

include "ms_sector.asy";
picture ms_sector = currentpicture;
currentpicture = new picture;

include "ra_consumer.asy";
picture ra_consumer = currentpicture;
currentpicture = new picture;


//size(500,500);

add(scale(Scale)*y_sector.fit(), (0,0));
add(scale(Scale)*a_sector.fit(), (Scale*image_size,0));

add(scale(Scale)*ms_sector.fit(), (0,-Scale*image_size));
add(scale(Scale)*ra_consumer.fit(), (Scale*image_size,-Scale*image_size));


