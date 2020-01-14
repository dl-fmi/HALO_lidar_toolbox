function [product, product_attribute, product_dimensions] = ...
    createHALOatmBLclassificationMasks(time,height,bitfield,fubarfield,dt_i)

category_bits = bitfield;

% Read bitfield
layer_bit = double(bitand(uint16(category_bits),uint16(1))>0);
epsilon_bit = double(bitand(uint16(category_bits),uint16(2))>0);
contact_bit = double(bitand(uint16(category_bits),uint16(4))>0);
heatflux_bit = double(bitand(uint16(category_bits),uint16(8))>0);
heatfluxabshi_bit = double(bitand(uint16(category_bits),uint16(16))>0);
shear_bit = double(bitand(uint16(category_bits),uint16(32))>0);
incloud_bit = double(bitand(uint16(category_bits),uint16(64))>0);
driven_bit = double(bitand(uint16(category_bits),uint16(128))>0);
convective_bit = double(bitand(uint16(category_bits),uint16(256))>0);
precipitation_bit = double(bitand(uint16(category_bits),uint16(512))>0);

%% Decision tree
% Stability
BL_mask = zeros(size(bitfield));
BL_mask(~heatfluxabshi_bit | (~heatflux_bit & heatfluxabshi_bit)) = 1;
BL_mask(heatflux_bit & heatfluxabshi_bit) = 2;
fill = BL_mask;

% Non-turbulentdt_i
BL_mask(~epsilon_bit & layer_bit) = 3;

% Turbulent
BL_mask(epsilon_bit & layer_bit) = 3.5;

% Convective mixing
BL_mask(BL_mask == 3.5 & heatflux_bit & heatfluxabshi_bit & contact_bit & layer_bit) = 4;
%BL_mask(convective_bit==1) = 4;

% In cloud
BL_mask(incloud_bit & layer_bit) = 7;
BL_mask(incloud_bit & ~layer_bit) = 7;

% Cloud driven
BL_mask(BL_mask == 3.5 & driven_bit == 1 & ~incloud_bit & layer_bit) = 8;

% Wind shear
BL_mask(BL_mask == 3.5 & (heatflux_bit==0 | heatfluxabshi_bit==0) & BL_mask~=7 & BL_mask~=8 & shear_bit & layer_bit) = 5;

% Decaying / intermittent
BL_mask(BL_mask == 3.5) = 6;

%% Clean up
BL_mask(:,1:3) = 0;
BL_mask(:,1:3) = fill(:,end-2:end);
BL_mask(~layer_bit & ~incloud_bit) = 0;
BL_mask(BL_mask ~= 1 & BL_mask ~= 2 & fubarfield == 0) = 0;
epsilon_mask = fubarfield;
epsilon_mask(:,1:3) = 0;
epsilon_mask(~layer_bit & ~incloud_bit) = 0;
epsilon_mask(epsilon_mask==6) = 2;
epsilon_mask(BL_mask==3) = 1;
BL_mask(epsilon_mask==1) = 3;
epsilon_mask(BL_mask==0) = 0;
BL_mask(epsilon_mask==0 & not(BL_mask==1 | BL_mask==2)) = 0;

% Add precipitation mask
BL_mask(any(precipitation_bit==1,2),4:end) = 9;
epsilon_mask(any(precipitation_bit==1,2),4:end) = 7;

%% Create product bl_classification
product.(['bl_classification_' dt_i]) = int8(BL_mask);

product_attribute.(['bl_classification_' dt_i]).long_name = 'Boundary layer classification';
product_attribute.(['bl_classification_' dt_i]).comment = ...
   ['This variable is a simplification of the bitfield in the boundary' ...
   ' layer classification dataset. It provides the main sources of' ...
   ' boundary layer mixing that can be distinguished by Doppler lidar' ...
   ' and possible supplementary inputs. The classes are defined in the' ...
   ' definition and long_definition attributes.'];

product_attribute.(['bl_classification_' dt_i]).plot_range = [0 9];
product_attribute.(['bl_classification_' dt_i]).definition = ...
   ['0: No signal' 10 ...
    '1: Stable/neutral' 10 ...
    '2: Unstable' 10 ...
    '3: Non-turbulent' 10 ...
    '4: Convective mixing' 10 ...
    '5: Wind shear' 10 ...
    '6: Intermittent' 10 ...
    '7: In cloud' 10 ...
    '8: Cloud-driven' 10 ...
    '9: Precipitation' 10];

product_attribute.(['bl_classification_' dt_i]).long_definition = ...
   ['0: No signal' 10 ...
    '1: Stable/neutral' 10 ...
    '2: Unstable' 10 ...
    '3: Non-turbulent' 10 ...
    '4: Convective mixing' 10 ...
    '5: Wind shear' 10 ...
    '6: Intermittent' 10 ...
    '7: In cloud' 10 ...
    '8: Cloud-driven' 10 ...
    '9: Precipitation' 10];

product_attribute.(['bl_classification_' dt_i]).dimensions = {['time_' dt_i]','range'};

% [1.0 0.4 0.7 0.4 1.0 0.0 0.0 1.0 0.5 1.0 0.0]
% [1.0 0.4 0.7 0.8 0.2 0.6 0.0 0.9 0.0 0.0 1.0]
% [1.0 0.4 0.7 1.0 0.2 0.6 1.0 0.0 0.5 1.0 0.5]
product_attribute.(['bl_classification_' dt_i]).legend_key_red =   [0.6602 0.5 1.0 0.4 0.9 0.0 1.0 0.5 1.0 0.8];
product_attribute.(['bl_classification_' dt_i]).legend_key_green = [0.6602 0.5 1.0 0.8 0.0 0.0 0.9 0.0 0.6 0.7];
product_attribute.(['bl_classification_' dt_i]).legend_key_blue =  [0.6602 0.6 1.0 1.0 0.2 1.0 0.2 0.5 0.0 0.5];

%% Turbulence coupling

epsilon_mask(epsilon_mask==6) = 2;
epsilon_mask(epsilon_mask==7) = 6;
product.(['turbulence_coupling_' dt_i]) = int8(epsilon_mask);

product_attribute.(['turbulence_coupling_' dt_i]).long_name = 'Turbulence coupled with';
product_attribute.(['turbulence_coupling_' dt_i]).comment = ...
   ['This variable provides information on the presence of high' ...
   ' turbulence that can be distinguished by Doppler lidar and' ...
   ' whether the turbulence can be associated with surface-connected or' ...
   ' cloud-driven turbulent sources. The classes are defined in the' ...
   ' definition and long_definition attributes.'];

product_attribute.(['turbulence_coupling_' dt_i]).plot_range = [0 5];
product_attribute.(['turbulence_coupling_' dt_i]).definition = ...
    ['0: No signal' 10 ...
     '1: Non-turbulent' 10 ...
     '2: Surface-connected' 10 ...
     '3: Cloud-driven' 10 ...
     '4: In cloud' 10 ...
     '5: Unconnected' 10 ...
     '6: Precipitation' 10];
product_attribute.(['turbulence_coupling_' dt_i]).long_definition = ...
    ['0: No signal' 10 ...
     '1: Non-turbulent' 10 ...
     '2: Surface-connected' 10 ...
     '3: Cloud-driven' 10 ...
     '4: In cloud' 10 ...
     '5: Unconnected' 10 ...
     '6: Precipitation' 10];

product_attribute.(['turbulence_coupling_' dt_i]).legend_key_red =   [0.6602 0.0 1.0 1.0 0.4 1.0 0.8];
product_attribute.(['turbulence_coupling_' dt_i]).legend_key_green = [0.6602 0.7 1.0 0.8 0.5 0.0 0.7];
product_attribute.(['turbulence_coupling_' dt_i]).legend_key_blue =  [0.6602 1.0 0.6 0.5 0.6 1.0 0.5];

product_attribute.(['turbulence_coupling_' dt_i]).dimensions = {['time_' dt_i],'range'};

%% Bitfield
product.(['bitfield_' dt_i]) = int16(bitfield);
product_attribute.(['bitfield_' dt_i]).long_name = 'Boundary layer classification bitfield';
product_attribute.(['bitfield_' dt_i]).comment = ...
   ['This variable is the bitfield of the boundary layer classification' ...
   ' dataset. See definition attribute for more information.'];

product_attribute.(['bitfield_' dt_i]).plot_range = [0 255];
product_attribute.(['bitfield_' dt_i]).definition = ...
   ['bit 1: inside aerosol layer' 10 ...
    ' bit 2: significant turbulence' 10 ...
    ' bit 3: surface-connected' 10 ...
    ' bit 4: surface stable/neutral' 10 ...
    ' bit 5: surface unstable' 10 ...
    ' bit 6: significant wind shear' 10 ...
    ' bit 7: in cloud' 10 ...
    ' bit 8: cloud-driven' 10 ...
    ' bit 9: convective' 10 ...
    ' bit 10: precipitation' 10];

product_attribute.(['bitfield_' dt_i]).long_definition = ...
    ['bit 1: inside aerosol layer' 10 ...
    ' bit 2: significant turbulence' 10 ...
    ' bit 3: surface-connected' 10 ...
    ' bit 4: surface stable/neutral' 10 ...
    ' bit 5: surface unstable' 10 ...
    ' bit 6: significant wind shear' 10 ...
    ' bit 7: in cloud' 10 ...
    ' bit 8: cloud-driven' 10 ...
    ' bit 9: convective' 10 ...
    ' bit 10: precipitation' 10];

product_attribute.(['bitfield_' dt_i]).dimensions = {['time_' dt_i],'range'};

%% time
product.(['time_' dt_i]) = time;
product_attribute.(['time_' dt_i]) = create_attributes(...
    {['time_' dt_i]},...
    'Decimal hours UTC', ...
    'Hours UTC',...
    [],...
    ['Discrete time steps, in ' dt_i ' temporal resolution.']);
product_attribute.(['time_' dt_i]).axis = 'T';

% Create dimensions
product_dimensions.(['time_' dt_i]) = length(time);

%% height

%product.height = height;

% Add height attribute
%product_attribute.height = create_attributes(...
%    {'height'},...
%    'Height above ground', ...
%    'm',...
%    [],...
%    ['Range*sin(elevation), assumes that the instrument is at' ...
%    ' ground level! If not, add the height of the instrument' ...
%    ' from the ground to the height variable.']);

% Height dimensions
%product_dimensions.height = length(height);


end
