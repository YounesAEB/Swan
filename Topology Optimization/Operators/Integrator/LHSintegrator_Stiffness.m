classdef LHSintegrator_Stiffness < LHSintegrator

    methods (Access = public)

        function LHS = compute(obj)
            lhs = obj.computeElementalLHS();
            LHS = obj.assembleMatrix(lhs);
        end

    end

    methods (Access = protected)

        function lhs = computeElementalLHS(obj)
            dNdx  = obj.fun.computeCartesianDerivatives(obj.quadrature);
            dVolu = obj.mesh.computeDvolume(obj.quadrature);
            nGaus = obj.quadrature.ngaus;
            nElem = size(dVolu,2);
            nNodE = size(dNdx,2);
            nDofE = nNodE*obj.fun.ndimf;
            lhs = zeros(nDofE,nDofE,nElem);
            Bcomp = obj.createBComputer(dNdx);
            for igaus = 1:nGaus
                Bmat = Bcomp.compute(igaus);
                dV(1,1,:) = dVolu(igaus,:)';
                Bt   = permute(Bmat,[2 1 3]);
                BtCB = pagemtimes(Bt, Bmat);
                lhs = lhs + bsxfun(@times, BtCB, dV);
            end
        end

    end

    methods (Access = private)

        function Bcomp = createBComputer(obj, dNdx)
            s.fun  = obj.fun;
            s.dNdx = dNdx;
            Bcomp = BMatrixComputer(s);
        end

        function LHS = assembleMatrix(obj, lhs)
            s.fun    = obj.fun; % !!!
            assembler = AssemblerFun(s);
            LHS = assembler.assemble(lhs);
        end

    end

end