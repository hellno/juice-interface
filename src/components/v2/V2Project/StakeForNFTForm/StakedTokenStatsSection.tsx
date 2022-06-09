import { Plural } from '@lingui/macro'
import { Col, Row } from 'antd'

import { ThemeContext } from 'contexts/themeContext'
import { useNFTGetSummaryStats } from 'hooks/v2/nft/NFTGetSummaryStats'
import { useContext } from 'react'
import { formattedNum } from 'utils/formatNumber'

import { VeNftToken } from 'models/v2/stakingNFT'

import { shadowCard } from 'constants/styles/shadowCard'

export interface StakedTokenStatsSectionProps {
  tokenSymbol: string
  userTokens: VeNftToken[]
}

export default function StakedTokenStatsSection({
  tokenSymbol,
  userTokens,
}: StakedTokenStatsSectionProps) {
  const { totalStaked, totalStakedPeriod } = useNFTGetSummaryStats(userTokens)
  const totalStakedPeriodInDays = totalStakedPeriod / (60 * 60 * 24)

  const { theme } = useContext(ThemeContext)
  return (
    <div style={{ ...shadowCard(theme), padding: 25, marginBottom: 10 }}>
      <h3>Staking Summary:</h3>
      <Row>
        <Col span={8}>
          <p>Total staked ${tokenSymbol}:</p>
          <p>Total staked period:</p>
        </Col>
        <Col span={16}>
          <p>
            {formattedNum(totalStaked)} ${tokenSymbol}
          </p>
          <p>
            {` ${totalStakedPeriodInDays} `}
            <Plural
              value={totalStakedPeriodInDays}
              one="day"
              other="days"
            />{' '}
          </p>
        </Col>
        <br />
      </Row>
    </div>
  )
}