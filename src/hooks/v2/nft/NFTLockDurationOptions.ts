import { BigNumber } from '@ethersproject/bignumber'

import { VEBANNY_CONTRACT_ADDRESS } from 'constants/v2/nft/nftProject'

import useV2ContractReader from '../contractReader/V2ContractReader'
import { useNFTContract } from './NFTContract'

export function useNFTLockDurationOptions() {
  return useV2ContractReader<BigNumber[]>({
    contract: useNFTContract(VEBANNY_CONTRACT_ADDRESS),
    functionName: 'lockDurationOptions',
  })
}