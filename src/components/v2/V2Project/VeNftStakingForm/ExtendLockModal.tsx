import { Form, Modal, Select } from 'antd'
import { VeNftProjectContext } from 'contexts/v2/veNftProjectContext'
import { BigNumber } from '@ethersproject/bignumber'
import { useContext, useEffect, useMemo, useState } from 'react'
import { detailedTimeString } from 'utils/formatTime'
import { ThemeContext } from 'contexts/themeContext'
import { useExtendLockTx } from 'hooks/veNft/transactor/ExtendLockTx'
import { NetworkContext } from 'contexts/networkContext'
import { VeNftToken } from 'models/subgraph-entities/veNft/venft-token'
import { t, Trans } from '@lingui/macro'
import { emitSuccessNotification } from 'utils/notifications'

type ExtendLockModalProps = {
  visible: boolean
  token: VeNftToken
  onCancel: VoidFunction
  onCompleted: VoidFunction
}

const ExtendLockModal = ({
  visible,
  token,
  onCancel,
  onCompleted,
}: ExtendLockModalProps) => {
  const { userAddress, onSelectWallet } = useContext(NetworkContext)
  const { tokenId } = token
  const { lockDurationOptions } = useContext(VeNftProjectContext)
  const [updatedDuration, setUpdatedDuration] = useState(0)
  const [loading, setLoading] = useState(false)
  const lockDurationOptionsInSeconds = useMemo(() => {
    return lockDurationOptions
      ? lockDurationOptions.map((option: BigNumber) => {
          return option.toNumber()
        })
      : []
  }, [lockDurationOptions])

  useEffect(() => {
    lockDurationOptionsInSeconds.length > 0 &&
      setUpdatedDuration(lockDurationOptionsInSeconds[0])
  }, [lockDurationOptionsInSeconds])

  const {
    theme: { colors },
  } = useContext(ThemeContext)

  const extendLockTx = useExtendLockTx()

  const extendLock = async () => {
    if (!userAddress && onSelectWallet) {
      onSelectWallet()
    }

    setLoading(true)

    const txSuccess = await extendLockTx(
      {
        tokenId,
        updatedDuration,
      },
      {
        onConfirmed() {
          setLoading(false)
          emitSuccessNotification(
            t`Extend lock successful. Results will be indexed in a few moments.`,
          )
          onCompleted()
        },
      },
    )

    if (!txSuccess) {
      setLoading(false)
    }
  }

  return (
    <Modal
      visible={visible}
      onCancel={onCancel}
      onOk={extendLock}
      okText={`Extend Lock`}
      confirmLoading={loading}
    >
      <h2>
        <Trans>Extend Lock</Trans>
      </h2>
      <div style={{ color: colors.text.secondary }}>
        <p>
          <Trans>Set an updated duration for your staking position.</Trans>
        </p>
      </div>
      <Form layout="vertical" style={{ width: '100%' }}>
        <Form.Item>
          <Select
            value={updatedDuration}
            onChange={val => setUpdatedDuration(val)}
          >
            {lockDurationOptionsInSeconds.map((duration: number) => {
              return (
                <Select.Option key={duration} value={duration}>
                  {detailedTimeString({
                    timeSeconds: duration,
                    fullWords: true,
                  })}
                </Select.Option>
              )
            })}
          </Select>
        </Form.Item>
      </Form>
    </Modal>
  )
}

export default ExtendLockModal