classdef P1DiscontinuousFunction < FeFunction
    
    properties (Access = public)
        
    end
    
    properties (Access = private)
        interpolation
    end
    
    properties (Access = private)
    end
    
    methods (Access = public)
        
        function obj = P1DiscontinuousFunction(cParams)
            obj.init(cParams)
            obj.createInterpolation();
        end

        function fxV = evaluate(obj, xV)
            func = obj.fValues;
            obj.interpolation.computeShapeDeriv(xV);
            shapes = obj.interpolation.shape;
            nNode  = size(shapes,1);
            nGaus  = size(shapes,2);
            nF     = size(func,1);
            nElem  = size(func,3);
            fxV = zeros(nF,nGaus,nElem);
            for kNode = 1:nNode
                shapeKJ = shapes(kNode,:,:);
                fKJ     = func(:,kNode,:);
                f = bsxfun(@times,shapeKJ,fKJ);
                fxV = fxV + f;
            end
        end

        function N = computeShapeFunctions(obj, quad)
            obj.mesh.computeInverseJacobian(quad,obj.interpolation);
%             obj.interpolation.computeShapeDeriv(xV);
            N = obj.interpolation.shape;
        end

        function dNdx  = computeCartesianDerivatives(obj,quad)
           nElem = size(obj.mesh.connec,1);
           nNode = obj.interpolation.nnode;
           nDime = obj.interpolation.ndime;
           nGaus = quad.ngaus;
           invJ  = obj.mesh.computeInverseJacobian(quad,obj.interpolation);
           dShapeDx  = zeros(nDime,nNode,nElem,nGaus);
           for igaus = 1:nGaus
               dShapes = obj.interpolation.deriv(:,:,igaus);
               for jDime = 1:nDime
                   invJ_JI   = invJ(:,jDime,:,igaus);
                   dShape_KJ = dShapes(jDime,:);
                   dSDx_KI   = bsxfun(@times, invJ_JI,dShape_KJ);
                   dShapeDx(:,:,:,igaus) = dShapeDx(:,:,:,igaus) + dSDx_KI;
               end
           end
           dNdx = dShapeDx;
        end   

        function gradFun = computeGradient(obj, quad)
            dNdx = obj.computeCartesianDerivatives(quad);
            nDimf = obj.ndimf;
            nDims = size(dNdx, 1); % derivX, derivY (mesh-related?)
            nNode = size(dNdx, 2);
            nElem = size(dNdx, 3);
            nGaus = size(dNdx, 4);
            

            cV = squeeze(obj.fValues);
            grad = zeros(nDims,nDimf, nElem, nGaus);
            for iGaus = 1:nGaus
                dNdx_g = dNdx(:,:,:,iGaus);
                for iDims = 1:nDims
                    for iNode = 1:nNode
                        dNdx_i = squeeze(dNdx_g(iDims, iNode,:));
                        %dNi = squeeze(dNdx(idim,iNode,:,igaus));
                        f = cV(iNode,:)';
                        gradV = dNdx_i.*f;
                        fG(:,1) = squeeze(grad(iDims,:,:,iGaus));
                        grad(iDims,:,:,iGaus) = fG + gradV;
                    end
                end
            end
            %  gradt(1,:,:,:) = grad;
            fVR = reshape(grad, [nDims*nDimf,nElem, nGaus]);
            s.fValues = fVR;
            s.mesh    = obj.mesh;
            s.quadrature = quad;
            gradFun = FGaussDiscontinuousFunction(s);
        end
        
        function fFine = refine(obj, m, mFine)
         %   mFineD = mFine.createDiscontinuousMesh();
            f = squeeze(obj.fValues);
            f = f(:);
            fEdges = obj.computeFunctionInEdges(m,f);
            fAll  = [f;fEdges];
            
            s.mesh    = mFine;
            s.fValues = fAll;
            p1fun = P1Function(s);
            fFine = p1fun.project('P1D');
        end

        function dofConnec = computeDofConnectivity(obj)
            nNodes = obj.mesh.nnodeElem*obj.mesh.nelem;
            nodes  = 1:nNodes;
            conne = reshape(nodes,obj.mesh.nnodeElem,obj.mesh.nelem)';
            nDimf  = obj.ndimf;
            nNodeE = size(conne, 2);
            nDofsE = nNodeE*nDimf;
            dofsElem  = zeros(nDofsE,size(conne,1));
            for iNode = 1:nNodeE
                for iUnkn = 1:nDimf
                    idofElem   = nDimf*(iNode - 1) + iUnkn;
                    globalNode = conne(:,iNode);
                    idofGlobal = nDimf*(globalNode - 1) + iUnkn;
                    dofsElem(idofElem,:) = idofGlobal;
                end
            end
            dofConnec = dofsElem;
        end

        function fV = getFvaluesAsVector(obj)
            ndims   = size(obj.fValues, 1);
            nelem   = size(obj.mesh.connec, 1);
            nnodeEl = size(obj.mesh.connec, 2);
            fV = reshape(obj.fValues, [ndims, nelem*nnodeEl])';
        end

        function plot(obj)
            fD = obj.getFvaluesAsVector();
            mD = obj.mesh.createDiscontinuousMesh();
            x = mD.coord(:,1);
            y = mD.coord(:,2);
            figure()
            for idim = 1:obj.ndimf
                subplot(1,obj.ndimf,idim);
                z = fD(:,idim);
                a = trisurf(mD.connec,x,y,double(z));
                view(0,90)
    %             colorbar
                shading interp
                a.EdgeColor = [0 0 0];
                title(['dim = ', num2str(idim)]);
            end
        end

        function plotContour(obj)
            fD = obj.getFvaluesAsVector();
            mD = obj.mesh.createDiscontinuousMesh();
            x = mD.coord(:,1);
            y = mD.coord(:,2);
            figure()
            for idim = 1:obj.ndimf
                subplot(1,obj.ndimf,idim);
                z = fD(:,idim);
                [~,a] = tricontour(mD.connec,x,y,z,30);
                set(a,'LineWidth',5);
                view(0,90)
                colorbar
                title(['dim = ', num2str(idim)]);
            end
        end

        function print(obj, s)
            s.mesh = obj.mesh.createDiscontinuousMesh();
            s.fun = {obj};
            p = FunctionPrinter(s);
            p.print();
        end

        function [res, pformat] = getDataToPrint(obj)
            nElem = size(obj.fValues, 3);
            nNodE = size(obj.fValues, 2);
            nNods = nElem*nNodE;
            s.nDimf   = obj.ndimf;
            s.nData   = nNods;
            s.nGroup  = nNods;
            s.fValues = obj.getFormattedFValues();
            fps = FunctionPrintingSettings(s);
            [res, pformat] = fps.getDataToPrint();
        end

    end


    methods (Access = public, Static)

        function fS = sum(f1,f2)
            fS = f1.fValues + f2.fValues;
            s.fValues = fS;
            s.mesh    = f1.mesh;
            fS = P1DiscontinuousFunction(s);
        end

        function p1d = create(mesh, ndimf)
            a.mesh    = mesh;
            a.fValues = zeros(ndimf, mesh.nnodeElem, mesh.nelem);
            p1d = P1DiscontinuousFunction(a);
        end

    end

    methods (Access = private)
        
        function init(obj,cParams)
            obj.fValues = cParams.fValues;
            obj.mesh    = cParams.mesh;
            obj.ndimf   = size(cParams.fValues,1);
            obj.order   = 'LINEAR';
        end

        function createInterpolation(obj)
            m.type = obj.mesh.type;
            obj.interpolation = Interpolation.create(m,'LINEAR');
        end

        % Printing
        function fM = getFormattedFValues(obj)
            nComp = obj.ndimf;
            nNodE = size(obj.fValues, 2);
            nElem = size(obj.fValues, 3);
            nVals = nNodE*nElem;
            fM = reshape(obj.fValues, [nComp, nVals])';
        end
        
        function f = computeFunctionInEdges(obj,m,fNodes)
            s.edgeMesh = m.computeEdgeMesh();
            s.fNodes   = fNodes;
            eF         = EdgeFunctionInterpolator(s);
            f = eF.compute();
        end
        
    end

    
end