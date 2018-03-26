function [ sdf ] = sphere_sdf( x,y,z,R)
sdf = x.^2 +y.^2 + z.^2;
end

