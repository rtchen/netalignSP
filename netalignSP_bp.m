function [mi] = netalignSP_bp(A,B,L,lambda,a,b,gamma,dtype,maxiter,verbose)



eps = 1e5;
if ~exist('lambda','var') || isempty(lambda), lambda=1; end
if ~exist('a','var') || isempty(a), a=1; end
if ~exist('b','var') || isempty(b), b=1; end
if ~exist('gamma','var') || isempty(gamma), gamma=0.99; end
if ~exist('dtype', 'var') || isempty(dtype), dtype=1; end
if ~exist('maxiter', 'var') || isempty(maxiter), maxiter=50; end
if ~exist('verbose', 'var') || isempty(verbose), verbose=1; end 

numBvertices = size(B,1);
numAvertices = size(A,1);

distA = floyd(A);
distB = floyd(B);
distA(1:numAvertices+1:end) = eps;
distB(1:numBvertices+1:end) = eps;

distA = 1./((distA).^lambda);
distB = 1./((distB).^lambda);
distAtrans = distA';
distBtrans = distB';

Le = zeros(nnz(L),3);
Ae = zeros(nnz(A),2);
Be = zeros(nnz(B),2);
nedgesL = size(Le,1);
nedgesA = size(Ae,1);
nedgesB = size(Be,1);

[Le(:,1) Le(:,2) Le(:,3)] = find(L);
[Ae(:,1) Ae(:,2)] = find(A);
[Be(:,1) Be(:,2)] = find(B);



% find vertice to edge mapping
indicesL = full(sparse(Le(:,1),Le(:,2),1:length(Le(:,1)),size(L,1),size(L,2)));
indicesA = full(sparse(Ae(:,1),Ae(:,2),1:length(Ae(:,1)),size(A,1),size(A,2)));
indicesB = full(sparse(Be(:,1),Be(:,2),1:length(Be(:,1)),size(B,1),size(B,2)));
indicesLtrans = indicesL';

m = max(Le(:,1));
n = max(Le(:,2));


% Initialize the messages

mfiii = zeros(nedgesL,1);
mgiii = zeros(nedgesL,1);
mpijii = zeros(nedgesA,nedgesL);
mpjiii = zeros(nedgesA,nedgesL);
mqijii = zeros(nedgesB,nedgesL);
mqjiii = zeros(nedgesB,nedgesL);
miifi = zeros(nedgesL,1);
miigi = zeros(nedgesL,1);
miipij = zeros(nedgesL,nedgesA);
miipji = zeros(nedgesL,nedgesA);
miiqij = zeros(nedgesL,nedgesB);
miiqji = zeros(nedgesL,nedgesB);

damping = gamma;
curdamp = 1;
iter = 1;
alpha = a;
beta = b;

% Initialize history
hista = zeros(maxiter,4); % history of messages from ei->a vertices
histb = zeros(maxiter,4); % history of messages from ei->b vertices
fbest = 0; fbestiter = 0;
[rp ci ai tripi matn matm] = bipartite_matching_setup(...
                                   Le(:,3),Le(:,1),Le(:,2),m,n);         
mperm = tripi(tripi>0); 
clear ai;

while iter<=maxiter
    prevmfiii = mfiii;
    prevmgiii = mgiii;
    prevmpijii = mpijii;
    prevmpjiii = mpjiii;
    prevmqijii = mqijii;
    prevmqjiii = mqjiii;
    prevmiifi = miifi;
    prevmiigi = miigi;
    prevmiipij = miipij;
    prevmiipji = miipji;
    prevmiiqij = miiqij;
    prevmiiqji = miiqji;
    curdamp = damping*curdamp;
    
    
    omaxfiii = max(othermaxplus(2,Le(:,1),Le(:,2),miifi,m,n,(1/2)*alpha*Le(:,3)),0);
    omaxgiii = max(othermaxplus(1,Le(:,1),Le(:,2),miigi,m,n,(1/2)*alpha*Le(:,3)),0);
    
    mfiii = (1/2)*alpha*Le(:,3) - omaxfiii;
    mgiii = (1/2)*alpha*Le(:,3) - omaxgiii;
    
    for ij=1:nedgesA
        i = Ae(ij,1);
        j = Ae(ij,2);  
        othermaxmikpij = othermaxplus(2,Le(:,1),Le(:,2),miipij(:,ij),m,n,zeros(nedgesL,1));
        omaxmikpij = maxplus(j,indicesL,miipij(:,ij));
        for iapos = 1:numBvertices
           idx = indicesL(i,iapos);
           if idx == 0
               continue;
           end
           omaxp1=max(maxpluspq(1,1,indicesL,j,miipij,ij,(1/4)*beta*distB,iapos),0);
           omaxsigma = maxsigma(i,j,iapos,miipij(:,ij),indicesL,(1/4)*beta*distB);
           omaxp2 = max(othermaxmikpij(idx),omaxmikpij);
           mpijii(ij,idx) = omaxp1 - max(max(omaxsigma,omaxp2),0);
        end        
    end
    
    
    for ji=1:nedgesA
        j = Ae(ji,1);
        i = Ae(ji,2);  
        othermaxmikpji = othermaxplus(2,Le(:,1),Le(:,2),miipji(:,ji),m,n,zeros(nedgesL,1));
        omaxmikpji = maxplus(j,indicesL,miipji(:,ji));
        for iapos = 1:numBvertices
           idx = indicesL(i,iapos);
           if idx == 0
               continue;
           end
           omaxp1=max(maxpluspq(1,2,indicesL,j,miipji,ji,(1/4)*beta*distB,iapos),0);
           omaxsigma = maxsigma(i,j,iapos,miipji(:,ji),indicesL,(1/4)*beta*distBtrans);
           omaxp2 = max(othermaxmikpji(idx),omaxmikpji);
           mpjiii(ji,idx) = omaxp1 - max(max(omaxsigma,omaxp2),0);
        end        
    end
    
     for ij=1:nedgesB
        iapos = Be(ij,1);
        japos = Be(ij,2);  
        othermaxmikqij = othermaxplus(1,Le(:,1),Le(:,2),miiqij(:,ij),m,n,zeros(nedgesL,1));
        omaxmikqij = maxplus(japos,indicesLtrans,miiqij(:,ij));
        for i = 1:numAvertices
           idx = indicesL(i,iapos);
           if idx == 0
               continue;
           end
           omaxq1=max(maxpluspq(2,1,indicesL,japos,miiqij,ij,(1/4)*beta*distA,i),0);
           omaxsigma = maxsigma(iapos,japos,i,miiqij(:,ij),indicesLtrans,(1/4)*beta*distA);
           omaxq2 = max(othermaxmikqij(idx),omaxmikqij);
           mqijii(ij,idx) = omaxq1 - max(max(omaxsigma,omaxq2),0);
        end        
     end 
    
    for ji=1:nedgesB
        japos = Be(ji,1);
        iapos = Be(ji,2);  
        othermaxmikqji = othermaxplus(1,Le(:,1),Le(:,2),miiqji(:,ji),m,n,zeros(nedgesL,1));
        omaxmikqji = maxplus(japos,indicesLtrans,miiqji(:,ji));
        for i = 1:numAvertices
           idx = indicesL(i,iapos);
           if idx == 0
               continue;
           end
           omaxq1=max(maxpluspq(2,2,indicesL,japos,miiqji,ji,(1/4)*beta*distA,iapos),0);
           omaxsigma = maxsigma(iapos,japos,i,miiqji(:,ji),indicesLtrans,(1/4)*beta*distAtrans);
           omaxq2 = max(othermaxmikqji(idx),omaxmikqji);
           mqjiii(ji,idx) = omaxq1 - max(max(omaxsigma,omaxq2),0);
        end        
    end
    
    minus1 = mpijii';
    minus2 = mpjiii';
    minus3 = mqijii';
    minus4 = mqjiii';
    for ii = 1:nedgesL
        i = Le(ii,1);
        iapos = Le(ii,2);
        neighSum = neighborSum(1,i,mpijii(:,ii),indicesA)+neighborSum(2,i,mpjiii(:,ii),indicesA)...
                    +neighborSum(1,iapos,mqijii(:,ii),indicesB)+neighborSum(2,iapos,mqjiii(:,ii),indicesB);
        miifi(ii) = mgiii(ii) + neighSum;
        miigi(ii) = mfiii(ii) + neighSum;
       
        tmp = mfiii(ii)+mgiii(ii)+neighSum;
        tmpVec = ones(1,nedgesA)*tmp;
        miipij(ii,:) = tmpVec - minus1(ii,:);
        miipji(ii,:) = tmpVec - minus2(ii,:);
        tmpVec = ones(1,nedgesB)*tmp;
        miiqij(ii,:) = tmpVec - minus3(ii,:);
        miiqji(ii,:) = tmpVec - minus4(ii,:);       
        
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if dtype ==1
        mfiii = curdamp*(mfiii)+(1-curdamp)*(prevmfiii);
        mgiii = curdamp*(mgiii)+(1-curdamp)*(prevmgiii);
        mpijii = curdamp*(mpijii)+(1-curdamp)*(prevmpijii);
        mpjiii = curdamp*(mpjiii)+(1-curdamp)*(prevmpjiii);
        mqijii = curdamp*(mqijii)+(1-curdamp)*(prevmqijii);
        mqjiii = curdamp*(mqjiii)+(1-curdamp)*(prevmqjiii);
        miifi = curdamp*(miifi)+(1-curdamp)*(prevmiifi);
        miigi = curdamp*(miigi)+(1-curdamp)*(prevmiigi);       
        miipij = curdamp*(miipij)+(1-curdamp)*(prevmiipij);
        miipji = curdamp*(miipji)+(1-curdamp)*(prevmiipji);
        miiqij = curdamp*(miiqij)+(1-curdamp)*(prevmiiqij);
        miiqji = curdamp*(miiqji)+(1-curdamp)*(prevmiiqji);
    end
    
    [hista(iter,:) mi1] = round_messages(miifi,Le(:,3),Le(:,1),Le(:,2),alpha,beta,rp,ci,tripi,matn,matm,mperm,distA,distB);
    [histb(iter,:) mi2]= round_messages(miigi,Le(:,3),Le(:,1),Le(:,2),alpha,beta,rp,ci,tripi,matn,matm,mperm,distA,distB);
    
    if hista(iter,1)>fbest
        fbestiter=iter;  fbest=hista(iter,1); mi = mi1;
    end
    if histb(iter,1)>fbest
        fbestiter=-iter;  fbest=histb(iter,1);mi = mi2;
    end
    
    if verbose
        if fbestiter==iter, bestchar='*a'; 
        elseif fbestiter==-iter, bestchar='*b';
        else bestchar='';
        end
        fprintf('%4s   %4i   %7g %7g %7i %7g   %7g %7g %7i %7g\n', ...
            bestchar, iter, hista(iter,:), histb(iter,:));
    end
    iter = iter+1;
    
end

end




%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function omp=othermaxplus(dim,li,lj,lw,m,n,alphaw)

if dim==1
    % max-plus over cols
    i1 = lj;
    i2 = li;
    N = n;
else
    % max-plus over rows
    i1 = li;
    i2 = lj;
    N = m;
end

dimmax1 =0*ones(N,1);      % largest value
dimmax2 = 0*ones(N,1);     % second largest value, 
dimmaxind = zeros(N,1);   % index of largest value
nedges = length(li);

for i=1:nedges
    if lw(i)+alphaw(i) > dimmax2(i1(i))
        if lw(i)+alphaw(i) > dimmax1(i1(i))
            dimmax2(i1(i)) = dimmax1(i1(i));
            dimmax1(i1(i)) = lw(i)+alphaw(i);
            dimmaxind(i1(i)) = i2(i);
        else
            dimmax2(i1(i)) = lw(i)+alphaw(i);
        end
    end 
end

omp = zeros(size(lw));
for i=1:nedges
    if i2(i) == dimmaxind(i1(i))
        omp(i) = dimmax2(i1(i));
    else
        omp(i) = dimmax1(i1(i));
    end
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function maxSum = maxpluspq(pq,dim,indicesL,j,message,ij, distM,iapos)
  nvertices = size(distM,1);
  maxSum = 0;
  for k = 1:nvertices
      if pq == 1
          idx = indicesL(j,k);
      else
          idx = indicesL(k,j);
      end
      if idx == 0
          continue
      end
      if dim==1 && distM(iapos,k)+message(idx,ij)>maxSum
          maxSum = distM(iapos,k)+message(idx,ij);
      elseif dim==2 && distM(k,iapos)+message(idx,ij)>maxSum
          maxSum = distM(k,iapos)+message(idx,ij);
      end      
  end

end

function max=maxplus(j,indicesL,lw)
nedges = size(indicesL,2);
max = 0;
for k=1:nedges
   idx = indicesL(j,k);
   if idx == 0
       continue;
   end
   if lw(idx) > max
       max = lw(idx);
   end
end 

end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function omp=maxsigma(i,j,iapos,lw,indicesL,dist)
nvertices = size(dist,1);
omp = 0;
for m = 1:nvertices
    if m == iapos
        continue;
    end
    idx1 = indicesL(i,m);
    if idx1==0
        continue;
    end
   for n = 1:nvertices
       idx2 = indicesL(j,n);
       if  idx2 ==0
           continue;
       end
       if dist(m,n)+lw(idx1)+lw(idx2) > omp
           omp = dist(m,n)+lw(idx1)+lw(idx2);
       end           
           
   end   
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function sum = neighborSum(dim,i,message,indicesM)
sum=0;
numvertices = size(indicesM,1);
for k = 1:numvertices
    if dim ==1
       idx = indicesM(i,k);
    else
       idx = indicesM(k,i);
    end
    if idx ==0
        continue;
    end
    sum = sum+message(idx);
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [info mi]=round_messages(messages,w,li,lj,alpha,beta,rp,ci,tripi,n,m,perm,distA,distB)
ai=zeros(length(tripi),1);
ai(tripi>0)=messages(perm);
[val ma mb mi]= bipartite_matching_primal_dual(rp,ci,ai,tripi,n,m);
matchweight = sum(w(mi)); cardinality = sum(mi); 
overlap = 0;
len = length(mi);
for ii = 1: len
    if mi(ii) == 0, continue; end
    i = li(ii);
    for jj = 1:len
        if mi(jj) == 0||ii==jj, continue; end
        j = li(jj);
        if distA(i,j) ~=1, continue; end
     %   fprintf('lj(ii)  %7i lj(jj) %7i distB %7g  \n', ...
     %   lj(ii), lj(jj),distB(lj(ii),lj(jj)));
        overlap = overlap + distB(lj(ii),lj(jj));
    end
end
for ii = 1: len
    if mi(ii) == 0, continue; end
    iapos = lj(ii);
    for jj = 1:len
        if mi(jj) == 0 || ii==jj, continue; end
        japos= lj(jj);
        if distB(iapos,japos) ~=1, continue; end
        overlap = overlap + distA(li(ii),li(jj));
    end
end
f = alpha*matchweight + (1/4)*beta*overlap;
info = [f matchweight cardinality overlap];
end


