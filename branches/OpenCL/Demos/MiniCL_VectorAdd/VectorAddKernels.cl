/*
Bullet Continuous Collision Detection and Physics Library, http://bulletphysics.org
Copyright (C) 2006 - 2009 Sony Computer Entertainment Inc. 

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from the use of this software.
Permission is granted to anyone to use this software for any purpose, 
including commercial applications, and to alter it and redistribute it freely, 
subject to the following restrictions:

1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.
*/

///GUID_ARG is only used by MiniCL to pass in the guid used by its get_global_id implementation
#ifndef GUID_ARG
#define GUID_ARG
#endif

///////////////////////////////////////////////////
// OpenCL Kernel Function for element by element vector addition
__kernel void VectorAdd(__global const float8* a, __global const float8* b, __global float8* c GUID_ARG)
{
    // get oct-float index into global data array
    int iGID = get_global_id(0);

    // read inputs into registers
    float8 f8InA = a[iGID];
    float8 f8InB = b[iGID];
    float8 f8Out = (float8)0.0f;
    
    // add the vector elements
    f8Out.s0 = f8InA.s0 + f8InB.s0;
    f8Out.s1 = f8InA.s1 + f8InB.s1;
    f8Out.s2 = f8InA.s2 + f8InB.s2;
    f8Out.s3 = f8InA.s3 + f8InB.s3;
    f8Out.s4 = f8InA.s4 + f8InB.s4;
    f8Out.s5 = f8InA.s5 + f8InB.s5;
    f8Out.s6 = f8InA.s6 + f8InB.s6;
    f8Out.s7 = f8InA.s7 + f8InB.s7;

    // write back out to GMEM
    c[get_global_id(0)] = f8Out;
}

__kernel void kPredictUnconstrainedMotion(	__global float4* pLinVel, 
											__global float4* pAngVel, 
											__global float4* pParams, 
											__global float4* pInvInertiaMass, 
											int numObjects,
											float timeStep GUID_ARG)
{
    unsigned int index = get_global_id(0);
	float4 mass0 =	pInvInertiaMass[index * 3 + 0];
    if(mass0.w > 0.f)
	{
		float4 linVel = pLinVel[index];
		float4 gravity = pParams[0];
		linVel += gravity * timeStep;
		pLinVel[index] = linVel;
	}
}

int4 getGridPos(float4 worldPos, __global float4* pParams)
{
    int4 gridPos;
    gridPos.x = (int)floor((worldPos.x - pParams[1].x) / pParams[2].x);
    gridPos.y = (int)floor((worldPos.y - pParams[1].y) / pParams[2].y);
    gridPos.z = (int)floor((worldPos.z - pParams[1].z) / pParams[2].z);
    return gridPos;
}

unsigned int getPosHash(int4 gridPos, __global float4* pParams)
{
	int4 pGridDim = *((int4*)(pParams + 3));
	if(gridPos.x < 0) gridPos.x = 0;
	if(gridPos.x >= pGridDim.x) gridPos.x = pGridDim.x - 1;
	if(gridPos.y < 0) gridPos.y = 0;
	if(gridPos.y >= pGridDim.y) gridPos.y = pGridDim.y - 1;
	if(gridPos.z < 0) gridPos.z = 0;
	if(gridPos.z >= pGridDim.z) gridPos.z = pGridDim.z - 1;
	unsigned int hash = gridPos.z * pGridDim.y * pGridDim.x + gridPos.y * pGridDim.x + gridPos.x;
	return hash;
} 


#if 0
int getObjectId(__global int2* pShapeIds, unsigned int numObjects, int sphereId)
{
	int found = -1;
	for(int i = 0; i < numObjects; i++)
	{
		int currId = pShapeIds[i].x;
		if(currId > sphereId)
		{
			break;
		}
		found++;
	}
	return found;
}

__kernel void kSetSpheres(	__global float4* pPos, 
							__global float4* pTrans,
							__global float4* pShapeBuf,
							__global int2* pShapeIds,
							__global int2* pPosHash,
							__global float4* pParams, 
							unsigned int numObjs)
{
    unsigned int index = get_global_id(0);
    int objId = getObjectId(pShapeIds, numObjs, index);

	float4 ai =	pTrans[objId * 4 + 0];
	float4 aj =	pTrans[objId * 4 + 1];
	float4 ak =	pTrans[objId * 4 + 2];
	float4 pos = pTrans[objId * 4 + 3];
	float4 shape = pShapeBuf[index];
	pos += ai * shape.x;
	pos += aj * shape.y;
	pos += ak * shape.z;
	pos.w = 1.0f;
	pPos[index] = pos;
	int4 gridPos = getGridPos(pos, pParams);
	unsigned int hash = getPosHash(gridPos, pParams);
	pPosHash[index].x = hash;
	pPosHash[index].y = index;
}
#else
__kernel void kSetSpheres(	__global float4* pPos, 
							__global float4* pTrans,
							__global float4* pShapeBuf,
							__global int* pBodyIds,
							__global int2* pPosHash,
							__global float4* pParams, 
							unsigned int numObjs GUID_ARG)
{
    unsigned int index = get_global_id(0);
    int objId = pBodyIds[index];

	float4 ai =	pTrans[objId * 4 + 0];
	float4 aj =	pTrans[objId * 4 + 1];
	float4 ak =	pTrans[objId * 4 + 2];
	float4 pos = pTrans[objId * 4 + 3];
	float4 shape = pShapeBuf[index];
	pos += ai * shape.x;
	pos += aj * shape.y;
	pos += ak * shape.z;
	pos.w = 1.0f;
	pPos[index] = pos;
	int4 gridPos = getGridPos(pos, pParams);
	unsigned int hash = getPosHash(gridPos, pParams);
	pPosHash[index].x = hash;
	pPosHash[index].y = index;
}
#endif

#if 1
float4 getRotation(__global float4* trans)
{
	float trace = trans[0].x + trans[1].y + trans[2].z;
	float temp[4];
	if(trace > 0.0f)
	{
		float s = native_sqrt(trace + 1.0f);
		temp[3] = s * 0.5f;
		s = 0.5f / s;
		temp[0] = (trans[1].z - trans[2].y) * s;
		temp[1] = (trans[2].x - trans[0].z) * s;
		temp[2] = (trans[0].y - trans[1].x) * s;
	}
	else
	{
		typedef float btMatrRow[4];
		__global btMatrRow* m_el = (__global btMatrRow*)trans;
		int i = m_el[0][0] < m_el[1][1] ? 
			(m_el[1][1] < m_el[2][2] ? 2 : 1) :
			(m_el[0][0] < m_el[2][2] ? 2 : 0); 
		int j = (i + 1) % 3;  
		int k = (i + 2) % 3;
		float s = native_sqrt(m_el[i][i] - m_el[j][j] - m_el[k][k] + 1.0f);
		temp[i] = s * 0.5f;
		s = 0.5f / s;
		temp[3] = (m_el[j][k] - m_el[k][j]) * s;
		temp[j] = (m_el[i][j] + m_el[j][i]) * s;
		temp[k] = (m_el[i][k] + m_el[k][i]) * s;
	}
	float4 q;
	q.x = temp[0];
	q.y = temp[1];
	q.z = temp[2];
	q.w = temp[3];
	return q;
}
#else
float4 getRotation(__global float* trans)
{
	float trace = trans[0*4+0] + trans[1*4+1] + trans[2*4+2];
	float temp[4];
	if(trace > 0.0f)
	{
		float s = native_sqrt(trace + 1.0f);
		temp[3] = s * 0.5f;
		s = 0.5f / s;
		temp[0] = (trans[1*4+2] - trans[2*4+1]) * s;
		temp[1] = (trans[2*4+0] - trans[0*4+2]) * s;
		temp[2] = (trans[0*4+1] - trans[1*4+0]) * s;
	}
	else
	{
		int i = trans[0*4+0] < trans[1*4+1] ? 
			(trans[1*4+1] < trans[2*4+2] ? 2 : 1) :
			(trans[0*4+0] < trans[2*4+2] ? 2 : 0); 
		int j = (i + 1) % 3;  
		int k = (i + 2) % 3;
		float s = native_sqrt(trans[i*4+i] - trans[j*4+j] - trans[k*4+k] + 1.0f);
		temp[i] = s * 0.5f;
		s = 0.5f / s;
		temp[3] = (trans[j*4+k] - trans[k*4+j]) * s;
		temp[j] = (trans[i*4+j] + trans[j*4+i]) * s;
		temp[k] = (trans[i*4+k] + trans[k*4+i]) * s;
	}
	float4 q;
	q.x = temp[0];
	q.y = temp[1];
	q.z = temp[2];
	q.w = temp[3];
	return q;
}
#endif

float4 quatMult(float4 q1, float4 q2)
{
	float4 q;
	q.x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y;
	q.y = q1.w * q2.y + q1.y * q2.w + q1.z * q2.x - q1.x * q2.z;
	q.z = q1.w * q2.z + q1.z * q2.w + q1.x * q2.y - q1.y * q2.x;
	q.w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z; 
	return q;
}

float4 quatNorm(float4 q)
{
	float len = native_sqrt(dot(q, q));
	if(len > 0.f)
	{
		q *= 1.f / len;
	}
	else
	{
		q.x = q.y = q.z = 0.f;
		q.w = 1.f;
	}
	return q;
}

void setRotation(float4 q, __global float4* trans) 
{
	float d = dot(q, q);
	float s = 2.0f / d;
	float xs = q.x * s,   ys = q.y * s,   zs = q.z * s;
	float wx = q.w * xs,  wy = q.w * ys,  wz = q.w * zs;
	float xx = q.x * xs,  xy = q.x * ys,  xz = q.x * zs;
	float yy = q.y * ys,  yz = q.y * zs,  zz = q.z * zs;
    trans[0].x = 1.0f - (yy + zz);
	trans[1].x = xy - wz;
	trans[2].x = xz + wy;
	trans[0].y = xy + wz;
	trans[1].y = 1.0f - (xx + zz);
	trans[2].y = yz - wx;
	trans[0].z = xz - wy;
	trans[1].z = yz + wx;
	trans[2].z = 1.0f - (xx + yy);
	trans[0].w = trans[1].w = trans[2].w = 0.0f;
}


#define BT_GPU_ANGULAR_MOTION_THRESHOLD (0.25f * 3.1415926f)

__kernel void kIntegrateTransforms(	__global float4* pLinVel, 
									__global float4* pAngVel, 
									__global float4* pParams, 
									__global float4* pTrans,
									__global float4* pInvInertiaMass, 
									int numObjects,
									float timeStep GUID_ARG)
{
    unsigned int index = get_global_id(0);
	float4 mass0 =	pInvInertiaMass[index * 3 + 0];
    if(mass0.w > 0.f)
	{
		float4 pos = pTrans[index * 4 + 3];
		float4 linVel = pLinVel[index];
		pos += linVel * timeStep;
		float4 axis;
		float4 angvel = pAngVel[index];
		float fAngle = native_sqrt(dot(angvel, angvel));
		//limit the angular motion
		if(fAngle*timeStep > BT_GPU_ANGULAR_MOTION_THRESHOLD)
		{
			fAngle = BT_GPU_ANGULAR_MOTION_THRESHOLD / timeStep;
		}
		if(fAngle < 0.001f)
		{
			// use Taylor's expansions of sync function
			axis = angvel * (0.5f*timeStep-(timeStep*timeStep*timeStep)*0.020833333333f * fAngle * fAngle);
		}
		else
		{
			// sync(fAngle) = sin(c*fAngle)/t
			axis = angvel * ( native_sin(0.5f * fAngle * timeStep) / fAngle);
		}
		float4 dorn = axis;
		dorn.w = native_cos(fAngle * timeStep * 0.5f);
		float4 orn0 = getRotation(pTrans + index * 4);
		float4 predictedOrn = quatMult(dorn, orn0);
		predictedOrn = quatNorm(predictedOrn);
		setRotation(predictedOrn, pTrans + index * 4);
		pTrans[index * 4 + 3] = pos;
	}
}



void findPairsInCell(	int4 gridPos,
						int index,
						float4 posA,
						__global float4* pPos, 
						__global int2*  pHash,
						__global int*   pCellStart,
						__global float4* pShapeBuff, 
						__global int* pBodyIds,
						__global uint*   pPairBuff,
						__global uint2*	pPairBuffStartCurr,
						__global float4* pParams)
{
	int4 pGridDim = *((int4*)(pParams + 3));
    if (	(gridPos.x < 0) || (gridPos.x > pGridDim.x - 1)
		||	(gridPos.y < 0) || (gridPos.y > pGridDim.y - 1)
		||  (gridPos.z < 0) || (gridPos.z > pGridDim.z - 1)) 
    {
		return;
	}
    int gridHash = getPosHash(gridPos, pParams);
    // get start of bucket for this cell
    int bucketStart = pCellStart[gridHash];
    if (bucketStart == -1)
	{
        return;   // cell empty
	}
	// iterate over spheres in this cell
    int2 sortedData = pHash[index];
	int unsorted_indx = sortedData.y;
	int bodyIdA = pBodyIds[unsorted_indx];
	int2 start_curr = pPairBuffStartCurr[unsorted_indx];
	int start = start_curr.x;
	int curr = start_curr.y;
	int2 start_curr_next = pPairBuffStartCurr[unsorted_indx+1];
	int bucketEnd = bucketStart + 8;
	for(int index2 = bucketStart; index2 < bucketEnd; index2++) 
	{
        int2 cellData = pHash[index2];
        if (cellData.x != gridHash)
        {
			break;   // no longer in same bucket
		}
		int unsorted_indx2 = cellData.y;
		int bodyIdB = pBodyIds[unsorted_indx2];
        if((bodyIdB != bodyIdA) && (unsorted_indx2 > unsorted_indx)) // check not colliding with self
        {   
			float4 posB = pPos[unsorted_indx2];
			posB.w = pShapeBuff[unsorted_indx2].w;
			float4 del = posB - posA;
			float dist2 = del.x * del.x + del.y * del.y + del.z * del.z;
			float rad2 = posB.w + posA.w;
			rad2 = rad2 * rad2;
			if((dist2 < rad2) && (curr < 12))
			{
				pPairBuff[start+curr] = unsorted_indx2;
				curr++;
			}
		}
	}
	pPairBuffStartCurr[unsorted_indx].y = curr;
    return;
}




__kernel void kBroadphaseCD(__global float4* pPos, 
							__global float4* pShapeBuf,
							__global int* pBodyIds,
							__global int2* pHash,
							__global int* pCellStart,
							__global int* pPairBuff,
							__global int2* pPairBuffStartCurr,
							__global float4* pParams GUID_ARG)
{
    unsigned int index = get_global_id(0);
    int2 sortedData = pHash[index];
	int unsorted_indx = sortedData.y;
	// clear pair buffer 
	pPairBuffStartCurr[unsorted_indx].y = 0;
	//
	// DEBUG : COULD BE REMOVED LATER
	//
	int buf_start_indx = pPairBuffStartCurr[unsorted_indx].x;
	int buf_sz = pPairBuffStartCurr[unsorted_indx+1].x - buf_start_indx;
	for(int i = 0; i < buf_sz; i++)
	{
		pPairBuff[buf_start_indx + i] = -1;
	}
    // get address in grid
	float4 pos = pPos[unsorted_indx];
    int4 gridPosA = getGridPos(pos, pParams);

	int4 pGridDim = *((int4*)(pParams + 3));
    if (	(gridPosA.x < 0) || (gridPosA.x > pGridDim.x - 1)
		||	(gridPosA.y < 0) || (gridPosA.y > pGridDim.y - 1)
		||  (gridPosA.z < 0) || (gridPosA.z > pGridDim.z - 1)) 
    {
		return;
	}
    
    pos.w = pShapeBuf[unsorted_indx].w;
    // examine only neighbouring cells
    int4 gridPosB; 
    for(int z=-1; z<=1; z++) 
    {
		gridPosB.z = gridPosA.z + z;
        for(int y=-1; y<=1; y++) 
        {
			gridPosB.y = gridPosA.y + y;
            for(int x=-1; x<=1; x++) 
            {
				gridPosB.x = gridPosA.x + x;
                findPairsInCell(gridPosB, index, pos, pPos, pHash, pCellStart, pShapeBuf, pBodyIds, pPairBuff, pPairBuffStartCurr, pParams);
            }
        }
    }
}
