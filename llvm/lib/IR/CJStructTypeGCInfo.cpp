//===-- IR/CJStructTypeGCInfo.cpp -- gc info utilities --------------------===//
//
// Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
// This source file is part of the Cangjie project, licensed under Apache-2.0
// with Runtime Library Exception.
//
// See https://cangjie-lang.cn/pages/LICENSE for license information.
//
//===----------------------------------------------------------------------===//
//
// This file contains utility functions to generate gc info for llvm types
//
//===----------------------------------------------------------------------===//

#include "llvm/IR/CJStructTypeGCInfo.h"
#include "llvm/ADT/Triple.h"

using namespace llvm;

TypeGCInfo &CJStructTypeGCInfo::getOrInsertTypeGCInfo(StructType *ST,
                                                      bool IsArrayType) {
  auto Itr = Type2GCInfo.find(ST);
  if (Itr != Type2GCInfo.end()) {
    return Itr->second;
  }

  if (IsArrayType) {
    return insertArrayTypeGCInfo(ST);
  }
  return insertNonArrayTypeGCInfo(ST);
}

TypeGCInfo &CJStructTypeGCInfo::insertArrayTypeGCInfo(StructType *ST) {
  // 2: ArrayLaout.xxx = type {%ArrayBase, [0 x type(i8*|prim|struct)]}
  assert(ST->getNumElements() == 2 && "ArrayLayout's elemNums should be 2");
  auto *AT = dyn_cast<ArrayType>(ST->getElementType(1));
  assert(AT != nullptr && "ArrayLayout[1] should be ArrayType");

  auto ElemType = AT->getElementType();
  // set size to element's size
  Type2GCInfo[ST].ObjSize =
      static_cast<uint32_t>(DL.getTypeAllocSize(ElemType).getFixedSize());
  auto Itr = Type2GCInfo.find(ST);
  Itr->second.ElementType = ElemType;
  StructType *ElemST = nullptr;
  if (ElemType->isStructTy()) {
    ElemST = dyn_cast<StructType>(ElemType);
  } else if (ElemType->isArrayTy()) {
    uint64_t NumElements = ElemType->getArrayNumElements();
    std::string ATElementTyName = "record.tmp" +
        ST->getName().substr(ST->getName().find('.')).str();
    ElemST = StructType::getTypeByName(M.getContext(), ATElementTyName);
    if (ElemST == nullptr) {
      std::vector<Type *> Elements;
      for (unsigned It = 0; It < NumElements; ++It) {
        Elements.push_back(ElemType->getArrayElementType());
      }
      ElemST = StructType::create(M.getContext(), ATElementTyName);
      ElemST->setBody(Elements);
    }
  }
  // structArray' BitMap is element struct's BitMap
  if (ElemST != nullptr) {
    auto &ElemTypeGCInfo = getOrInsertTypeGCInfo(ElemST);
    Itr->second.BMInfo = ElemTypeGCInfo.BMInfo;
  } else if (isReferenceType(ElemType)) {
    Itr->second.BMInfo.HasRef = true;
  }
  return Itr->second;
}

void CJStructTypeGCInfo::getOrInsertArrayTypeGCInfo(
    ArrayType *AT, BitMapInfo &BMInfo, uint64_t &CurSize) {
  auto NumElements = AT->getArrayNumElements();
  auto ET = AT->getArrayElementType();
  unsigned Idx = 0;
  while (Idx < NumElements) {
    Idx++;
    if (ET->isArrayTy()) {
      getOrInsertArrayTypeGCInfo(dyn_cast<ArrayType>(ET), BMInfo, CurSize);
      continue;
    }
    fillBMInfo(ET, BMInfo, CurSize);
  }
}

void CJStructTypeGCInfo::fillBMInfo(Type *Ty, BitMapInfo &BMInfo,
                                    uint64_t &CurSize) {
  if (Ty->isStructTy()) { // it is a value type
    auto &SubInfo = getOrInsertTypeGCInfo(dyn_cast<StructType>(Ty));
    BMInfo.HasRef |= SubInfo.BMInfo.HasRef;
    if (SubInfo.BMInfo.HasRef) {
      assert(CurSize % PtrSize == 0 && "CurSize must be PtrSize aligned");
      BMInfo.BMStr.replace(CurSize / PtrSize, SubInfo.BMInfo.BMStr.length(),
                           SubInfo.BMInfo.BMStr);
    }
  } else if (isReferenceType(Ty)) {
    // set 1 for addr pointer
    BMInfo.BMStr[CurSize / PtrSize] = '1';
    BMInfo.HasRef = true;
  }
  CurSize += DL.getTypeAllocSize(Ty).getFixedSize();
}

TypeGCInfo &CJStructTypeGCInfo::insertNonArrayTypeGCInfo(StructType *ST) {
  // init new TypeGCInfo
  Type2GCInfo[ST].ObjSize =
      static_cast<uint32_t>(DL.getTypeAllocSize(ST).getFixedSize());
  auto Itr = Type2GCInfo.find(ST);
  Itr->second.BMInfo.HasRef = false;
  // 1 bit represent 1 PtrSize(4 bytes or 8 bytes)
  Itr->second.BMInfo.BMStr =
      std::string((Itr->second.ObjSize + PtrSize - 1) / PtrSize, '0');
  unsigned Idx = 0;
  uint64_t CurSize = 0;
  while (Idx < ST->getNumElements()) {
    auto *SubType = ST->getElementType(Idx);
    auto SubAlign = DL.getABITypeAlignment(SubType);
    CurSize = (CurSize + SubAlign - 1) & (~(SubAlign - 1));

    if (auto AT = dyn_cast<ArrayType>(SubType)) {
      getOrInsertArrayTypeGCInfo(AT, Itr->second.BMInfo, CurSize);
    } else {
      fillBMInfo(SubType, Itr->second.BMInfo, CurSize);
    }
    ++Idx;
  }
  if (!Itr->second.BMInfo.HasRef) {
    Itr->second.BMInfo.BMStr = std::string();
  }

  uint64_t AlignSize = CurSize;
  auto STAlign = DL.getABITypeAlignment(ST);
  AlignSize = (AlignSize + STAlign - 1) & (~(STAlign - 1));
  assert(CurSize == Itr->second.ObjSize || AlignSize == Itr->second.ObjSize);
  return Itr->second;
}

Constant *CommonBitmap::insertBitMapU64(const std::string &BMStr,
                                        Type *CommonBMType) {
  uint64_t Value = 0;
  for (unsigned I = 0, J = BMStr.length(); I < J; ++I) {
    if (BMStr[I] == '1') {
      Value |= (uint64_t)1 << I;
    }
  }
  Value |= (uint64_t)1 << 63;
  auto bitmap = ConstantInt::get(Type::getInt64Ty(M.getContext()), Value);
  return ConstantExpr::getIntToPtr(bitmap, CommonBMType);
}

Constant *CommonBitmap::insertBitMapGV(const std::string &BMStr,
                                       Type *CommonBMType,
                                       const std::string &BitMapName) {
  std::string AlignedBMStr = BMStr;
  unsigned BMStrLen = AlignedBMStr.length();
  unsigned AlignStrLen = ((BMStrLen + 7) & (~7)) - BMStrLen;
  if (AlignStrLen != 0) {
    AlignedBMStr += std::string(AlignStrLen, '0');
  }
  unsigned BodySize = AlignedBMStr.length() / 8; // 8: to calculate Bytes
  // create ST: {int32, int8[]}
  SmallVector<Type *, 8> TypeBody(BodySize + 1,
                                  Type::getInt8Ty(M.getContext()));
  TypeBody[0] = Type::getInt32Ty(M.getContext());
  auto *BMType =
      llvm::StructType::create(M.getContext(), TypeBody, "BitMapInstance");
  // creat bitMap global value
  SmallVector<Constant *, 8> BMBody(BodySize + 1); // 8: preset size of vector
  int CurIdx = 0;
  BMBody[CurIdx++] =
      ConstantInt::get(Type::getInt32Ty(M.getContext()), BodySize);
  unsigned Value = 0;
  for (unsigned I = 0, J = AlignedBMStr.length(); I < J; ++I) {
    if (AlignedBMStr[I] == '1') {
      Value |= 1 << (I % 8); // 8: string to char, 8 bits of every char
    }
    if ((I + 1) % 8 == 0) { // 8: string to char, 8 bits of every char
      BMBody[CurIdx++] =
          ConstantInt::get(Type::getInt8Ty(M.getContext()), Value);
      Value = 0;
    }
  }

  auto *BMGlobalVariable =
      cast<GlobalVariable>(M.getOrInsertGlobal(BitMapName + ".bitmap", BMType));
  BMGlobalVariable->setInitializer(ConstantStruct::get(BMType, BMBody));
  BMGlobalVariable->setLinkage(GlobalVariable::LinkOnceODRLinkage);
  BMGlobalVariable->setVisibility(GlobalVariable::HiddenVisibility);
  BMGlobalVariable->addAttribute("CFileGCTib");
  return ConstantExpr::getBitCast(BMGlobalVariable, CommonBMType);
}

Constant *CommonBitmap::getOrInsertBitMap(const std::string &BMStr,
                                          Type *CommonBMType,
                                          const std::string &BitMapName) {
  std::string KeyStr = BMStr;
  unsigned KeyStrLen = KeyStr.length();
  // 7: aligned to 8
  unsigned AlignStrLen = ((KeyStrLen + 7) & (~7)) - KeyStrLen;
  if (AlignStrLen != 0) {
    KeyStr += std::string(AlignStrLen, '0');
  }

  auto Itr = BitMapStr2Constant.find(KeyStr);
  // use first generated bitmap const's name for all same bitmap in the module
  if (Itr != BitMapStr2Constant.end()) {
    return Itr->second;
  }

  Constant *BMConst = nullptr;
  if (BMStr.length() < 64 && !Triple(M.getTargetTriple()).isARM()) {
    BMConst = insertBitMapU64(BMStr, CommonBMType);
  } else {
    BMConst = insertBitMapGV(KeyStr, CommonBMType, BitMapName);
  }

  BitMapStr2Constant[KeyStr] = BMConst;
  return BMConst;
}
