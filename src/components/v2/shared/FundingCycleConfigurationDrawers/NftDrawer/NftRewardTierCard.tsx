import { Button, Col, Image, Row, Tooltip } from 'antd'
import Paragraph from 'components/Paragraph'
import { ThemeContext } from 'contexts/themeContext'
import { NftRewardTier } from 'models/v2/nftRewardTier'
import { useContext, useState } from 'react'
import {
  LinkOutlined,
  DeleteOutlined,
  LoadingOutlined,
} from '@ant-design/icons'
import { Trans } from '@lingui/macro'

import NftRewardTierModal from './NftRewardTierModal'

export default function NftRewardTierCard({
  rewardTier,
  onChange,
  onDelete,
}: {
  rewardTier: NftRewardTier
  onChange: (rewardTier: NftRewardTier) => void
  onDelete: VoidFunction
}) {
  const {
    theme: { colors },
  } = useContext(ThemeContext)

  const [editTierModalVisible, setEditTierModalVisible] =
    useState<boolean>(false)
  const [linkHover, setLinkHover] = useState<boolean>(false)
  const [imageLoading, setImageLoading] = useState<boolean>(true)

  if (!rewardTier) return null
  return (
    <>
      <Row
        style={{
          background: colors.background.l0,
          border: `1px solid ${colors.stroke.tertiary}`,
          display: 'flex',
          width: '100%',
          cursor: 'pointer',
          padding: '15px 8px 15px 20px',
        }}
        onClick={() => setEditTierModalVisible(true)}
      >
        <Col
          md={16}
          style={{
            display: 'flex',
            justifyContent: 'center',
            flexDirection: 'column',
          }}
        >
          <Row
            style={{
              display: 'flex',
              alignItems: 'center',
              fontSize: 17,
              width: '100%',
            }}
          >
            <Col style={{ color: colors.text.action.primary }} md={7}>
              {rewardTier.contributionFloor} ETH
            </Col>
            <Col style={{ display: 'flex', fontWeight: 500 }} md={15}>
              <span>{rewardTier.name}</span>
              {rewardTier.externalLink ? (
                <a
                  href={rewardTier.externalLink}
                  onClick={e => e.stopPropagation()}
                  onMouseEnter={() => {
                    setLinkHover(true)
                  }}
                  onMouseLeave={() => {
                    setLinkHover(false)
                  }}
                  style={{
                    marginLeft: 10,
                    color: linkHover
                      ? colors.text.action.primary
                      : colors.text.primary,
                  }}
                >
                  <LinkOutlined />
                </a>
              ) : null}
            </Col>
          </Row>
          {rewardTier.description && (
            <div style={{ fontSize: 13, marginTop: 15 }}>
              <Paragraph
                description={rewardTier.description}
                characterLimit={74}
              />
            </div>
          )}
        </Col>
        <Col
          md={5}
          style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
          }}
        >
          {imageLoading ? (
            <LoadingOutlined style={{ fontSize: '30px' }} />
          ) : null}
          <Image
            src={rewardTier.imageUrl}
            alt={rewardTier.name}
            height={'90px'}
            style={{
              display: imageLoading ? 'none' : 'unset',
              objectFit: 'cover',
              maxWidth: '90px',
            }}
            onLoad={() => setImageLoading(false)}
            onClick={e => e.stopPropagation()}
          />
        </Col>
        <Col md={3}>
          <Tooltip title={<Trans>Delete NFT</Trans>}>
            <Button
              type="text"
              onClick={e => {
                onDelete()
                // prevent opening modal
                e.stopPropagation()
              }}
              icon={<DeleteOutlined />}
              style={{ height: 16, float: 'right' }}
            />
          </Tooltip>
        </Col>
      </Row>
      <NftRewardTierModal
        visible={editTierModalVisible}
        rewardTier={rewardTier}
        mode="Edit"
        onClose={() => setEditTierModalVisible(false)}
        onChange={onChange}
        isCreate
      />
    </>
  )
}
