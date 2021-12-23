classdef WSN_Battery_Topology_Simulation < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        WSN_LEACH                   matlab.ui.Figure
        TabGroup                    matlab.ui.container.TabGroup
        TopologyTab                 matlab.ui.container.Tab
        UIAxes                      matlab.ui.control.UIAxes
        NodesDeadvsTimeTab          matlab.ui.container.Tab
        UIAxes2                     matlab.ui.control.UIAxes
        BatteryLifevsTimeTab        matlab.ui.container.Tab
        UIAxes3                     matlab.ui.control.UIAxes
        SettingsPanel               matlab.ui.container.Panel
        CHChangeRateEditField       matlab.ui.control.NumericEditField
        CHChangeRateEditFieldLabel  matlab.ui.control.Label
        CompressmAhEditField        matlab.ui.control.NumericEditField
        CompressmAhEditFieldLabel   matlab.ui.control.Label
        BatterymAhEditField         matlab.ui.control.NumericEditField
        BatterymAhEditFieldLabel    matlab.ui.control.Label
        CHTransmAhEditField         matlab.ui.control.NumericEditField
        CHTransmAhEditFieldLabel    matlab.ui.control.Label
        SimDelaysEditField          matlab.ui.control.NumericEditField
        SimDelaysEditFieldLabel     matlab.ui.control.Label
        EdgesEditField              matlab.ui.control.EditField
        EdgesLabel                  matlab.ui.control.Label
        NodesEditField              matlab.ui.control.EditField
        NodesLabel                  matlab.ui.control.Label
        PresetsDropDown             matlab.ui.control.DropDown
        PresetsDropDownLabel        matlab.ui.control.Label
        SimulateButton              matlab.ui.control.Button
        WSNLifeGauge                matlab.ui.control.LinearGauge
        WSNLifeGaugeLabel           matlab.ui.control.Label
        SelectedTextArea            matlab.ui.control.TextArea
        SelectedTextAreaLabel       matlab.ui.control.Label
    end

    
    properties (Access = public)
    end
    
    methods (Access = private)
        % This simulation program can be used to find the most suitable
        % topolgy for most wireless sensor network applications.
        % Information co9llected includes:
        % average packet generation/s, animation time, 
        % real time relation to animation time, 
        % battery capacitance, rate clusterhead is chosen
        % distributions of data rate (poisson vs. fixed), 
        % battery depleted for on time/transmission/ch transmission, 
        % battery depleted for overhead
        % whether graph is weighted or not
        % statistics on length of time network lasted, first node to die, 
        % last node to die, 
        % when each node died or just a percentage still alive
        
        function results = randn(countnodes)
            results = randi([1 countnodes]);
        end
        
        %function for selecting the clusterhead
        function results = sel_CH(app, countnodes, mAh)
            results = randi([1 length(mAh)]);
            % verify that the node is not dead
            while (mAh(results) == 0.0)
                results = randi([1 length(mAh)]);
            end
        end
        
        %NOTE: nodes are declared dead after they no longer have the battery to transmit to the BS
        %function for battery cost of compression transmission
        function [batt, dead] = batt_cost_compress(app, mAh, nodex, num_dead)
            dead = num_dead;
            mAh(nodex) = mAh(nodex) - app.CompressmAhEditField.Value;
            if (mAh(nodex) - app.CHTransmAhEditField.Value < 0)
                mAh(nodex) = 0;
                dead = num_dead + 1;
            end
            batt = mAh(nodex);
        end
        
        %function for battery cost of clusterhead to basestation transmission
        function [batt, dead] = batt_cost_CH(app, mAh, nodex, num_dead)
            dead = num_dead;
            mAh(nodex) = mAh(nodex) - app.CHTransmAhEditField.Value;
            if (mAh(nodex) - app.CHTransmAhEditField.Value < 0)
                mAh(nodex) = 0;
                dead = num_dead + 1;
            end
            batt = mAh(nodex);
        end
        
        function SIMULATE_LEACH(app)
            n = str2num(app.NodesEditField.Value);
            e = str2num(app.EdgesEditField.Value);
            G = graph(n,e);
            countnodes = numnodes(G);
            p = plot(app.UIAxes, G);
            ch_num = 0; % number of times node has been chosen as clusterhead
            dead_time = 0; % time node died
            num_dead = 0; % number node died starting from 0
            delay = app.SimDelaysEditField.Value;
            uptime = 0;
            firstdeadtime = 0;
            mAh = app.BatterymAhEditField.Value*ones([numnodes(G) 1]); % battery left in milliAmp/hours
            nodes = 1:countnodes;
            CHChange = app.CHChangeRateEditField.Value;
            if (CHChange < 1)
                CHChange = 1;
                app.CHChangeRateEditField.Value = 1;
            end
            ratecounter = 0;
            counter = 1;
            %initialize the clusterhead
            nodex = sel_CH(app, countnodes, mAh);
            numdeadY = zeros(1,100000, 'uint32');
            numdeadX = zeros(1,100000, 'double');
            totbattY = zeros(1,100000, 'double');
            
            for i = 1:countnodes
                highlight(p,i,'NodeColor','b',"MarkerSize", 20);
            end
            
            while num_dead < countnodes
                ratecounter = ratecounter + 1;
                if ratecounter >= CHChange || mAh(nodex) == 0
                    nodex = sel_CH(app, countnodes, mAh);
                    if ratecounter < CHChange
                        uptime = uptime + abs(delay*(CHChange-ratecounter));
                    end
                    ratecounter = 0;
                end
                % find neighbors
                connected = neighbors(G,nodex);
                s_nodex = abs(20*mAh(nodex)/app.BatterymAhEditField.Value)+0.1;
                highlight(p,nodex,'NodeColor','g',"MarkerSize", s_nodex);
                %           p(nodex).MarkerSize = 7*(mAh(nodex)/app.BatterymAhEditField.Value);
                for j = 1:length(connected)
                    if mAh(connected(j)) > 0
                        [mAh(connected(j)), num_dead] = batt_cost_compress(app, mAh, connected(j), num_dead);
                        highlight(p,[nodex connected(j)],'edgecolor','r', 'LineWidth', 5);
                        highlight(p,connected(j), "MarkerSize", 20*abs(mAh(connected(j))/app.BatterymAhEditField.Value)+0.1);
                        % Keep track of number dead
                        numdeadX(counter) = uptime + j*delay/length(connected);
                        numdeadY(counter) = num_dead;
                        % calculate the total battery of the system
                        totbattY(counter) = sum(mAh);
                        counter = counter + 1;
                        %                        p(connected(j)).MarkerSize = 7*(mAh(nodex)/app.BatterymAhEditField.Value);
                        line1 = sprintf('UpTime (s): %0.2f   Dead Nodes: %d',uptime + delay/length(connected), num_dead);
                        line2 = sprintf('ClusterHead: %d', nodex);
                        line3 = sprintf('Transmitting Node: %d', connected(j));
                        line4 = sprintf('Remaining Battery: ');
                        line5 = sprintf('%0.1f   ', (mAh./app.BatterymAhEditField.Value.*100));
                        app.SelectedTextArea.Value = {line1; line2; line3; line4; line5};
                        pause(delay);
                         highlight(p,[nodex connected(j)],'EdgeColor','b', 'linewidth', 1);
                        if mAh(connected(j)) > 0
                            highlight(p, connected(j),'NodeColor','b',"MarkerSize", 20*abs(mAh(connected(j))/app.BatterymAhEditField.Value)+0.1);
                        else
                            highlight(p,connected(j),'NodeColor','r',"MarkerSize", 20);
                        end
                    end
                    %figure out when the first node death occurs
                    if num_dead == 1
                        firstdeadtime = uptime;
                    end 
                end
                uptime = uptime + delay;
                [mAh(nodex), num_dead] = batt_cost_CH(app, mAh, nodex, num_dead);
                if num_dead == 1 && firstdeadtime == 0
                        firstdeadtime = uptime;
                end 
                numdeadX(counter) = uptime;
                numdeadY(counter) = num_dead;
                totbattY(counter) = sum(mAh);
                counter = counter + 1;
                if mAh(nodex) > 0
                    highlight(p,nodex,'NodeColor','b',"MarkerSize", 20*abs(mAh(nodex)/app.BatterymAhEditField.Value)+0.1);
                else
                    highlight(p,nodex,'NodeColor','r',"MarkerSize", 20);
                end
                %         p(nodex).MarkerSize = 7*(mAh(nodex)/app.BatterymAhEditField.Value);
                app.WSNLifeGauge.Value = 100*(countnodes - num_dead)/countnodes;
                pause(delay);
            end
            
            %Mark last nodes
            for i = 1:countnodes
                highlight(p,i,'NodeColor','r',"MarkerSize", 20);
            end
            
            line1 = sprintf('UpTime (s): %0.2f\nDead Nodes: %d\nFirst Node Death: %0.2f\n# of Transmissions: %d',uptime, num_dead, firstdeadtime, counter);
            app.SelectedTextArea.Value = {line1};
            
            %Plot graph information
            plot(app.UIAxes2,numdeadX(1:counter-1),numdeadY(1:counter-1));
            plot(app.UIAxes3,numdeadX(1:counter-1),totbattY(1:counter-1));
        end
        
        function LEACH(app)
            n = str2num(app.NodesEditField.Value);
            e = str2num(app.EdgesEditField.Value);
            G = graph(n,e);
            %number of nodes
            countnodes = numnodes(G);
            %p = app.UIAxes.plot(G,'Layout','force');
            p = plot(app.UIAxes, G);
            delay = app.SimDelaysEditField.Value;
            % select a random node
            i = randn(countnodes);
            connected = neighbors(G,i);
            for j = 1:length(connected)
                while app.PauseButton.Value == 1
                end
                highlight(p,i,'NodeColor','g')
                if connected(j) > i
                    highlight(p,[i connected(j)],'edgecolor','r');
                    line1 = sprintf('Selected Node: %d', i);
                    line2 = sprintf('Selected Edge: (%d,%d)', i, connected(j));
                    app.SelectedTextArea.Value = {line1; line2};
                    pause(delay)
                end
            end
        end
        
        
        function propogate(app)
            %demonstration function that searches through a graph
            n = str2num(app.NodesEditField.Value);
            e = str2num(app.EdgesEditField.Value);
            G = graph(n,e);
            %number of nodes
            countnodes = numnodes(G);
            %p = app.UIAxes.plot(G,'Layout','force');
            p = plot(app.UIAxes, G);
            delay = app.SimDelaysEditField.Value;
            mAh = app.BatterymAhEditField.Value*ones([numnodes(G) 1]); % battery left in milliAmp/hours
            %fig = app.SelectedTextArea;
            %farea = uitextarea(fig);
            for i = 1:countnodes
                connected = neighbors(G,i);
                for j = 1:length(connected)
                    %        while app.PauseButton.Value == 1
                    %        end
                    highlight(p,i,'NodeColor','g')
                    if connected(j) > i
                        %            line([p.XData(i),p.XData(connected(j))], ...
                        %                [p.YData(i),p.YData(connected(j))],'color','red', ...
                        %                'LineWidth',1.5)
                        highlight(p,[i connected(j)],'edgecolor','r');
                        mAh(connected(j)) = batt_cost(app, mAh, connected(j));
                        line3 = sprintf('milliamphour: %d  %0.3f', length(mAh), mAh(5));
                        line1 = sprintf('Selected Node: %d', i);
                        line2 = sprintf('Selected Edge: (%d,%d)', i, connected(j));
                        line4 = sprintf('%0.3d ', mAh);
                        app.SelectedTextArea.Value = {line3; line1; line2; line4};
                        %app.SelectedTextArea.Value = 'Selected Node: ' + i + newline + "Selected Edge: (" + i + ',' + connected(j) + ")";
                        pause(delay)
                    end
                end
            end
        end
        
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Value changed function: NodesEditField
        function NodesEditFieldValueChanged(app, event)
            value = app.NodesEditField.Value;
        end

        % Value changed function: EdgesEditField
        function EdgesEditFieldValueChanged(app, event)
            value = app.EdgesEditField.Value;
        end

        % Value changed function: SimDelaysEditField
        function SimDelaysEditFieldValueChanged(app, event)
            value = app.SimDelaysEditField.Value;
            app.SimDelaysEditField.Value = abs(app.SimDelaysEditField.Value);
        end

        % Value changed function: PresetsDropDown
        function PresetsDropDownValueChanged(app, event)
            % This function contains all the presets and example topologies
            
            value = app.PresetsDropDown.Value;
            if value == "Mesh 1"
                app.NodesEditField.Value = '1 2 2 3 3 3 4 5 5 8 8 5 11 12 12';
                app.EdgesEditField.Value = '2 3 4 1 4 5 5 6 7 9 10 10 6 3 10';
                app.SimDelaysEditField.Value = 0.5;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 3.2;
                app.CompressmAhEditField.Value = 0.1;
            elseif value == "Mesh 2"
                app.NodesEditField.Value = '1 2 2 3 3 3 4 5 5 8 8 5 11 12 12 13 14';
                app.EdgesEditField.Value = '2 3 4 1 4 5 5 6 7 9 10 10 6 3 10 5 7';
                app.SimDelaysEditField.Value = 0.05;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 10;
                app.CompressmAhEditField.Value = 0.1;
            elseif value == "Mesh Topology"
                app.NodesEditField.Value = '2 3 5 8 4 1 2 3 6 2 4 6 7 8 3';
                app.EdgesEditField.Value = '1 1 2 5 5 4 4 8 8 8 9 7 3 6 2';
                app.SimDelaysEditField.Value = 0.05;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 10;
                app.CompressmAhEditField.Value = 0.1;
            elseif value == "Star Topology"
                app.NodesEditField.Value = '1 2 3 4 5 6 7 8 9';
                app.EdgesEditField.Value = '2 9 2 2 2 2 2 2 2';
                app.SimDelaysEditField.Value = 0.05;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 10;
                app.CompressmAhEditField.Value = 0.1;
            elseif value == "Ring Topology"
                app.NodesEditField.Value = '1 2 3 4 5 6 7 8 9';
                app.EdgesEditField.Value = '9 8 2 1 3 7 4 6 5';
                app.SimDelaysEditField.Value = 0.05;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 10;
                app.CompressmAhEditField.Value = 0.1;
            elseif value == "Line Topology"
                app.NodesEditField.Value = '1 1 2 3 4 5 6 7 8 9';
                app.EdgesEditField.Value = '1 2 3 4 5 6 7 8 9 9';
                app.SimDelaysEditField.Value = 0.05;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 10;
                app.CompressmAhEditField.Value = 0.1;
            elseif value == "Hybrid Topology"
                app.NodesEditField.Value = '1 1 1 1 1 1 1 1 2 2 2 2 2 2 2 2 3 3 3 3 3 3 3 3 4 4 4 4 4 4 4 4 5 5 5 5 5 5 5 5 6 6 6 6 6 6 6 6 7 7 7 7 7 7 7 7 8 8 8 8 8 8 8 8 9 9 9 9 9 9 9 9';
                app.EdgesEditField.Value = '2 3 4 5 6 7 8 9 1 3 4 5 6 7 8 9 1 2 4 5 6 7 8 9 1 2 3 5 6 7 8 9 1 2 3 4 6 7 8 9 1 2 3 4 5 7 8 9 1 2 3 4 5 6 8 9 1 2 3 4 5 6 7 9 1 2 3 4 5 6 7 8';
                app.SimDelaysEditField.Value = 0.05;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 10;
                app.CompressmAhEditField.Value = 0.1;
            elseif value == "Tree Topology"
                app.NodesEditField.Value = '1 2 3 4 5 6 7 8 9';
                app.EdgesEditField.Value = '3 3 6 6 6 9 9 9 3';
                app.SimDelaysEditField.Value = 0.05;
                app.CHTransmAhEditField.Value = 0.5;
                app.BatterymAhEditField.Value = 10;
                app.CompressmAhEditField.Value = 0.1;
            else
                app.NodesEditField.Value = '';
                app.EdgesEditField.Value  = '';
                app.SimDelaysEditField.Value = 0;
            end
        end

        % Button pushed function: SimulateButton
        function SimulateButtonPushed(app, event)
            % Here is the main simulation call
            SIMULATE_LEACH(app);
        end

        % Value changed function: SelectedTextArea
        function SelectedTextAreaValueChanged(app, event)
            value = app.SelectedTextArea.Value;
        end

        % Callback function
        function PauseButtonValueChanged(app, event)
            value = app.PauseButton.Value;
            app.PauseButton.Value = abs(app.PauseButton.Value);
        end

        % Value changed function: BatterymAhEditField
        function BatterymAhEditFieldValueChanged(app, event)
            value = app.BatterymAhEditField.Value;
            app.BatterymAhEditField.Value = abs(app.BatterymAhEditField.Value);
        end

        % Value changed function: CHTransmAhEditField
        function CHTransmAhEditFieldValueChanged(app, event)
            value = app.CHTransmAhEditField.Value;
            app.CHTransmAhEditField.Value = abs(app.CHTransmAhEditField.Value);
        end

        % Value changed function: CompressmAhEditField
        function CompressmAhEditFieldValueChanged(app, event)
            value = app.CompressmAhEditField.Value;
            app.CompressmAhEditField.Value = abs(app.CompressmAhEditField.Value);
        end

        % Value changed function: CHChangeRateEditField
        function CHChangeRateEditFieldValueChanged(app, event)
            value = app.CHChangeRateEditField.Value;
            app.CHChangeRateEditField.Value = abs(app.CHChangeRateEditField.Value);
            
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create WSN_LEACH and hide until all components are created
            app.WSN_LEACH = uifigure('Visible', 'off');
            app.WSN_LEACH.Position = [100 100 692 545];
            app.WSN_LEACH.Name = 'UI Figure';

            % Create SelectedTextAreaLabel
            app.SelectedTextAreaLabel = uilabel(app.WSN_LEACH);
            app.SelectedTextAreaLabel.HorizontalAlignment = 'right';
            app.SelectedTextAreaLabel.Position = [296 170 56 22];
            app.SelectedTextAreaLabel.Text = 'Selected:';

            % Create SelectedTextArea
            app.SelectedTextArea = uitextarea(app.WSN_LEACH);
            app.SelectedTextArea.ValueChangedFcn = createCallbackFcn(app, @SelectedTextAreaValueChanged, true);
            app.SelectedTextArea.Position = [367 28 189 166];

            % Create WSNLifeGaugeLabel
            app.WSNLifeGaugeLabel = uilabel(app.WSN_LEACH);
            app.WSNLifeGaugeLabel.HorizontalAlignment = 'center';
            app.WSNLifeGaugeLabel.Position = [568 18 96 22];
            app.WSNLifeGaugeLabel.Text = 'WSN Life Gauge';

            % Create WSNLifeGauge
            app.WSNLifeGauge = uigauge(app.WSN_LEACH, 'linear');
            app.WSNLifeGauge.Orientation = 'vertical';
            app.WSNLifeGauge.Position = [591 46 43 148];

            % Create SettingsPanel
            app.SettingsPanel = uipanel(app.WSN_LEACH);
            app.SettingsPanel.Title = 'Settings';
            app.SettingsPanel.Position = [12 43 260 490];

            % Create SimulateButton
            app.SimulateButton = uibutton(app.SettingsPanel, 'push');
            app.SimulateButton.ButtonPushedFcn = createCallbackFcn(app, @SimulateButtonPushed, true);
            app.SimulateButton.Position = [90 64 100 22];
            app.SimulateButton.Text = 'Simulate';

            % Create PresetsDropDownLabel
            app.PresetsDropDownLabel = uilabel(app.SettingsPanel);
            app.PresetsDropDownLabel.HorizontalAlignment = 'right';
            app.PresetsDropDownLabel.Position = [79 422 46 22];
            app.PresetsDropDownLabel.Text = 'Presets';

            % Create PresetsDropDown
            app.PresetsDropDown = uidropdown(app.SettingsPanel);
            app.PresetsDropDown.Items = {'None', 'Mesh 1', 'Mesh 2', 'Mesh Topology', 'Star Topology', 'Ring Topology', 'Line Topology', 'Hybrid Topology', 'Tree Topology'};
            app.PresetsDropDown.ValueChangedFcn = createCallbackFcn(app, @PresetsDropDownValueChanged, true);
            app.PresetsDropDown.Position = [135 422 100 22];
            app.PresetsDropDown.Value = 'None';

            % Create NodesLabel
            app.NodesLabel = uilabel(app.SettingsPanel);
            app.NodesLabel.HorizontalAlignment = 'right';
            app.NodesLabel.Position = [73 373 47 22];
            app.NodesLabel.Text = {'Nodes[]'; ''};

            % Create NodesEditField
            app.NodesEditField = uieditfield(app.SettingsPanel, 'text');
            app.NodesEditField.ValueChangedFcn = createCallbackFcn(app, @NodesEditFieldValueChanged, true);
            app.NodesEditField.Position = [135 373 100 22];

            % Create EdgesLabel
            app.EdgesLabel = uilabel(app.SettingsPanel);
            app.EdgesLabel.HorizontalAlignment = 'right';
            app.EdgesLabel.Position = [74 330 46 22];
            app.EdgesLabel.Text = 'Edges[]';

            % Create EdgesEditField
            app.EdgesEditField = uieditfield(app.SettingsPanel, 'text');
            app.EdgesEditField.ValueChangedFcn = createCallbackFcn(app, @EdgesEditFieldValueChanged, true);
            app.EdgesEditField.Position = [135 330 100 22];

            % Create SimDelaysEditFieldLabel
            app.SimDelaysEditFieldLabel = uilabel(app.SettingsPanel);
            app.SimDelaysEditFieldLabel.HorizontalAlignment = 'right';
            app.SimDelaysEditFieldLabel.Position = [42 285 78 22];
            app.SimDelaysEditFieldLabel.Text = 'Sim Delay (s)';

            % Create SimDelaysEditField
            app.SimDelaysEditField = uieditfield(app.SettingsPanel, 'numeric');
            app.SimDelaysEditField.Limits = [0 Inf];
            app.SimDelaysEditField.ValueChangedFcn = createCallbackFcn(app, @SimDelaysEditFieldValueChanged, true);
            app.SimDelaysEditField.Position = [135 285 100 22];

            % Create CHTransmAhEditFieldLabel
            app.CHTransmAhEditFieldLabel = uilabel(app.SettingsPanel);
            app.CHTransmAhEditFieldLabel.HorizontalAlignment = 'right';
            app.CHTransmAhEditFieldLabel.Position = [25 197 95 22];
            app.CHTransmAhEditFieldLabel.Text = 'CH Trans. (mAh)';

            % Create CHTransmAhEditField
            app.CHTransmAhEditField = uieditfield(app.SettingsPanel, 'numeric');
            app.CHTransmAhEditField.ValueChangedFcn = createCallbackFcn(app, @CHTransmAhEditFieldValueChanged, true);
            app.CHTransmAhEditField.Position = [135 197 100 22];

            % Create BatterymAhEditFieldLabel
            app.BatterymAhEditFieldLabel = uilabel(app.SettingsPanel);
            app.BatterymAhEditFieldLabel.HorizontalAlignment = 'right';
            app.BatterymAhEditFieldLabel.Position = [41 243 79 22];
            app.BatterymAhEditFieldLabel.Text = 'Battery (mAh)';

            % Create BatterymAhEditField
            app.BatterymAhEditField = uieditfield(app.SettingsPanel, 'numeric');
            app.BatterymAhEditField.ValueChangedFcn = createCallbackFcn(app, @BatterymAhEditFieldValueChanged, true);
            app.BatterymAhEditField.Position = [135 243 100 22];

            % Create CompressmAhEditFieldLabel
            app.CompressmAhEditFieldLabel = uilabel(app.SettingsPanel);
            app.CompressmAhEditFieldLabel.HorizontalAlignment = 'right';
            app.CompressmAhEditFieldLabel.Position = [24 154 96 22];
            app.CompressmAhEditFieldLabel.Text = 'Compress (mAh)';

            % Create CompressmAhEditField
            app.CompressmAhEditField = uieditfield(app.SettingsPanel, 'numeric');
            app.CompressmAhEditField.ValueChangedFcn = createCallbackFcn(app, @CompressmAhEditFieldValueChanged, true);
            app.CompressmAhEditField.Position = [135 154 100 22];

            % Create CHChangeRateEditFieldLabel
            app.CHChangeRateEditFieldLabel = uilabel(app.SettingsPanel);
            app.CHChangeRateEditFieldLabel.HorizontalAlignment = 'right';
            app.CHChangeRateEditFieldLabel.Position = [23 113 97 22];
            app.CHChangeRateEditFieldLabel.Text = 'CH Change Rate';

            % Create CHChangeRateEditField
            app.CHChangeRateEditField = uieditfield(app.SettingsPanel, 'numeric');
            app.CHChangeRateEditField.ValueChangedFcn = createCallbackFcn(app, @CHChangeRateEditFieldValueChanged, true);
            app.CHChangeRateEditField.Position = [135 113 100 22];

            % Create TabGroup
            app.TabGroup = uitabgroup(app.WSN_LEACH);
            app.TabGroup.Position = [275 197 410 336];

            % Create TopologyTab
            app.TopologyTab = uitab(app.TabGroup);
            app.TopologyTab.Title = 'Topology';

            % Create UIAxes
            app.UIAxes = uiaxes(app.TopologyTab);
            title(app.UIAxes, 'Simulated WSN')
            xlabel(app.UIAxes, 'X')
            ylabel(app.UIAxes, 'Y')
            app.UIAxes.PlotBoxAspectRatio = [1.38315789473684 1 1];
            app.UIAxes.Position = [21 21 368 269];

            % Create NodesDeadvsTimeTab
            app.NodesDeadvsTimeTab = uitab(app.TabGroup);
            app.NodesDeadvsTimeTab.Title = 'Nodes Dead vs. Time';

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.NodesDeadvsTimeTab);
            title(app.UIAxes2, 'Nodes Dead vs. Time')
            xlabel(app.UIAxes2, 'Time (seconds)')
            ylabel(app.UIAxes2, 'Nodes Dead')
            app.UIAxes2.Position = [17 21 372 274];

            % Create BatteryLifevsTimeTab
            app.BatteryLifevsTimeTab = uitab(app.TabGroup);
            app.BatteryLifevsTimeTab.Title = 'Battery Life vs. Time';

            % Create UIAxes3
            app.UIAxes3 = uiaxes(app.BatteryLifevsTimeTab);
            title(app.UIAxes3, 'System Battery Life vs. Time')
            xlabel(app.UIAxes3, 'Time (seconds)')
            ylabel(app.UIAxes3, 'System Battery Life (mAh)')
            app.UIAxes3.Position = [21 21 368 269];

            % Show the figure after all components are created
            app.WSN_LEACH.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = WSN_Battery_Topology_Simulation

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.WSN_LEACH)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.WSN_LEACH)
        end
    end
end