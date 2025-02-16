classdef DilationComputer < handle

    properties (Access = private)
        LHS
        RHS
    end
    
    properties (Access = private)
        mesh
        orientationVector
        dilation
    end
    
    methods (Access = public)
        
        function obj = DilationComputer(cParams)
            obj.init(cParams);
            obj.createDilationFun();
        end

        function rF = compute(obj)
            obj.computeLHS();
            obj.computeRHS();
            r = obj.solveSystem();
            s.mesh = obj.mesh;
            s.fValues = r;
            rF = P1Function(s);
        end
        
    end
    
    methods (Access = private)
        
        function init(obj,cParams)
            obj.mesh               = cParams.mesh;
            obj.orientationVector  = cParams.orientationVector;
        end
       
        function computeLHS(obj)
            K = obj.computeStiffnessMatrix();
            I = ones(size(K,1),1);
            obj.LHS = [K,I;I',0];
        end
        
        function K = computeStiffnessMatrix(obj)
            s.fun  = obj.dilation;
            s.mesh = obj.mesh;
            s.type = 'StiffnessMatrix';
            lhs = LHSintegrator.create(s);
            K = lhs.compute();
        end

        function createDilationFun(obj)
            obj.dilation = P1Function.create(obj.mesh, 1);
        end
        
        function computeRHS(obj)
            q = Quadrature.set(obj.mesh.type);
            q.computeQuadrature('CUBIC');
            s.fType     = 'Gauss';
            s.fGauss    = obj.computeFieldTimesDivField(q);
            s.xGauss    = q.posgp;
            s.mesh      = obj.mesh;
            s.type      = obj.mesh.type;
            s.quadOrder = q.order;
            s.npnod     = obj.mesh.nnodes;
            s.type      = 'ShapeDerivative';
            s.globalConnec = obj.mesh.connec;
            rhs  = RHSintegrator.create(s);
            rhsV = rhs.compute();
            obj.RHS = [rhsV;0];
        end
        
        function gradT = computeFieldTimesDivField(obj,q)
            a1    = obj.orientationVector{1};
            a2    = obj.orientationVector{2};
            aDa1  = a1.computeFieldTimesDivergence(q);
            aDa2  = a2.computeFieldTimesDivergence(q);
            gradT = -aDa1.fValues - aDa2.fValues;
        end
        
        function u = solveSystem(obj)
            a.type = 'DIRECT';
            s = Solver.create(a);
            u = s.solve(obj.LHS,obj.RHS);
            u = u(1:end-1);
        end
        
    end
    
end