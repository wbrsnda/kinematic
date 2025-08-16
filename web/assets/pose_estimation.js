import * as mpTasks from '/assets/mediapipe/vision_bundle.mjs';

// 配置参数
const CONFIG = {
  ROI: {
    LEFT: { left: 0.00, top: 0, right: 0.00, bottom: 0, color: '#FF0000' },
    RIGHT: { left: 0.00, top: 0, right: 0.00, bottom: 0, color: '#0000FF' }
  },
  MODEL: 'lite', // 统一使用Lite模型
  TRACKING: {
    MIN_DETECTION_CONFIDENCE: 0.7,
    MIN_TRACKING_CONFIDENCE: 0.6
  },
  GAME: {
    PLAYER_ANIMATION_DURATION: 3000,  // 玩家准备时长
    GAME_ANIMATION_DURATION:   10000,  // 倒计时时长
    PLAY_DURATION:            60000,  // 游戏时长
    BUFFER_DURATION:          5000,   // 缓冲时长
    SETTLEMENT_COUNTDOWN:     20000,  // 结算时长
  }
};

// 状态管理
const state = {
  left: { pose: null, baseline: 0, jumps: 0, isLocked: false, lockProgress: 0, hasPerson: false, isPrepared: false, isJumping: false },
  right: { pose: null, baseline: 0, jumps: 0, isLocked: false, lockProgress: 0, hasPerson: false, isPrepared: false, isJumping: false },
  phase: 'registration',     // 当前游戏阶段：registration, playing, ended
  phaseStartTime: 0,         // 阶段开始时间戳
  gameStarting: false,       // 是否已启动倒计时
  countdownStart: null,      // 倒计时开始时间戳
  gameEnded: false,          // gameEnded 标志
  gameResult: false ,         // 结算结果阶段标志
  endedStartTime  : 0 // 结算阶段开始时间戳
};

let video = null;
let canvas = null;
let poseLeft = null;
let ctx = null;
let poseRight = null;
let offLeft = null, offRight = null;
let offCtxL = null, offCtxR = null;
let lastTimestamp = 0;

function updateGameConfig(jsonStringConfig) {
  console.log('⚙️ 收到外部配置原始字符串：', jsonStringConfig);
  try {
    const externalConfig = JSON.parse(jsonStringConfig); // 解析 JSON 字符串

    CONFIG.GAME.PLAYER_ANIMATION_DURATION = externalConfig.playerAnimationDuration ?? CONFIG.GAME.PLAYER_ANIMATION_DURATION;
    CONFIG.GAME.GAME_ANIMATION_DURATION   = externalConfig.gameAnimationDuration   ?? CONFIG.GAME.GAME_ANIMATION_DURATION;
    CONFIG.GAME.PLAY_DURATION             = externalConfig.gameplayDuration        ?? CONFIG.GAME.PLAY_DURATION;
    CONFIG.GAME.BUFFER_DURATION           = externalConfig.bufferDuration          ?? CONFIG.GAME.BUFFER_DURATION;
    CONFIG.GAME.SETTLEMENT_COUNTDOWN      = externalConfig.settlementCountdown     ?? CONFIG.GAME.SETTLEMENT_COUNTDOWN;
    
    // **新增：更新 ROI 参数**
    if (externalConfig.roi1) {
      CONFIG.ROI.LEFT.left   = externalConfig.roi1.left;
      CONFIG.ROI.LEFT.top    = externalConfig.roi1.top;
      CONFIG.ROI.LEFT.right  = externalConfig.roi1.right;
      CONFIG.ROI.LEFT.bottom = externalConfig.roi1.bottom;
    }
    if (externalConfig.roi2) {
      CONFIG.ROI.RIGHT.left   = externalConfig.roi2.left;
      CONFIG.ROI.RIGHT.top    = externalConfig.roi2.top;
      CONFIG.ROI.RIGHT.right  = externalConfig.roi2.right;
      CONFIG.ROI.RIGHT.bottom = externalConfig.roi2.bottom;
    }
    console.log('⚙️ CONFIG 更新后：', CONFIG);
  } catch (e) {
    console.error('❌ 解析外部配置失败：', e, '接收到的字符串：', jsonStringConfig);
  }
}
window.updateGameConfig = updateGameConfig;

// 初始化
window.initPoseEstimator = async function (videoElement, canvasElement) {
  try {
    const vision = await mpTasks.FilesetResolver.forVisionTasks('./assets/wasm');

    // 创建两个Lite实例
    [poseLeft, poseRight] = await Promise.all([
      createPoseInstance(vision),
      createPoseInstance(vision)
    ]);

    video = videoElement;
    canvas = canvasElement;
    ctx = canvas.getContext('2d');

    // 初始化离屏Canvas
    const init = () => {
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;

      // ROI区域尺寸
      const createOffscreen = (roi) => {
        const c = document.createElement('canvas');
        // **修复点：使用新的 left 和 right 属性来计算宽度**
        const width = video.videoWidth * (roi.right - roi.left);
        const height = video.videoHeight * (roi.bottom - roi.top);
        c.width = width > 0 ? width : 1; // 确保宽度大于0
        c.height = height > 0 ? height : 1; // 确保高度大于0
        return c;
      };

      offLeft = createOffscreen(CONFIG.ROI.LEFT);
      offRight = createOffscreen(CONFIG.ROI.RIGHT);
      offCtxL = offLeft.getContext('2d');
      offCtxR = offRight.getContext('2d');

      // 启动循环
      requestAnimationFrame(processFrame);
    };

    video.readyState >= 2 ? init()
      : video.addEventListener('loadeddata', init, { once: true });

  } catch (e) {
    console.error('初始化失败:', e);
  }
};

async function createPoseInstance(vision) {
  return mpTasks.PoseLandmarker.createFromOptions(vision, {
    baseOptions: {
      modelAssetPath: `./assets/models/pose_landmarker_${CONFIG.MODEL}.task`,
      delegate: 'GPU'
    },
    runningMode: 'VIDEO',
    numPoses: 1,
    minDetectionConfidence: CONFIG.TRACKING.MIN_DETECTION_CONFIDENCE,
    minTrackingConfidence: CONFIG.TRACKING.MIN_TRACKING_CONFIDENCE
  });
}

// 主循环
function processFrame() {
  if (!poseLeft || !poseRight || !video) return;

  // === 插入：阶段调度调用 ===
  switch (state.phase) {
    case 'registration':
      registrationPhase();
      break;
    case 'playing':
      playingPhase();
      break;
    case 'ended':
      endedPhase();
      break; // 停止后续处理
  }

  // 生成严格递增的时间戳
  const timestamp = generateTimestamp();

  // 并行处理左右区域
  Promise.all([
    processROI('left', offLeft, offCtxL, CONFIG.ROI.LEFT, timestamp),
    processROI('right', offRight, offCtxR, CONFIG.ROI.RIGHT, timestamp)
  ]).then(() => {
    requestAnimationFrame(processFrame);
  }).catch(handleError);
}

function generateTimestamp() {
  const now = performance.now();
  lastTimestamp = now > lastTimestamp ? now : lastTimestamp + 1;
  return lastTimestamp;
}

// **修复后的 processROI 函数**
async function processROI(side, offCanvas, offCtx, roi, timestamp) {
  const x = canvas.width * roi.left;
  const y = canvas.height * roi.top;
  const width = canvas.width * (roi.right - roi.left);
  const height = canvas.height * (roi.bottom - roi.top);

  if (width <= 0 || height <= 0) {
    console.warn(`无效的ROI区域（${side}）： width=${width}, height=${height}`);
    return;
  }

  // 裁剪区域：将视频的 ROI 部分绘制到离屏 Canvas
  offCtx.drawImage(video, x, y, width, height, 0, 0, offCanvas.width, offCanvas.height);

  // VIDEO模式检测
  const result = await (side === 'left' ? poseLeft : poseRight)
    .detectForVideo(offCanvas, timestamp);

  if (result.landmarks.length > 0 && isBigEnough(result.landmarks[0])) {
    updateState(side, result.landmarks[0], x);
  } else {
    state[side].pose = null;
  }
}

// ====== 骨架大小过滤 ======
/**
 * 根据肩膀与臀部的归一化 y 值差异判断人体是否足够大
 * @param {Array} landmarks - 33 个关键点数组
 * @returns {boolean}
 */
function isBigEnough(landmarks) {
  const yTop = Math.min(landmarks[11].y, landmarks[12].y);
  const yBot = Math.max(landmarks[23].y, landmarks[24].y);
  const height = yBot - yTop;      // 归一化高度
  return height > 0.15;             // 阈值可根据场景调整
}


function updateState(side, landmarks, offsetX) {
  const st = state[side];

  // 坐标转换
  const converted = landmarks.map(pt => ({
    x: (pt.x * offLeft.width + offsetX) / canvas.width,
    y: pt.y,
    z: pt.z
  }));

  // 平滑处理
  st.pose = st.pose ? converted.map((lm, i) => ({
    x: lm.x * 0.3 + st.pose[i].x * 0.7,
    y: lm.y * 0.3 + st.pose[i].y * 0.7,
    z: lm.z * 0.3 + st.pose[i].z * 0.7
  })) : converted;
}

function initBaseline(st) {
  const keyPoints = [11, 12, 23, 24];
  st.baseline = keyPoints.reduce((s, i) => s + st.pose[i].y, 0) / keyPoints.length;
}

function detectJump(st) {
  const currentY = getBodyCenter(st.pose);
  const threshold = getBodyHeight(st.pose) * 0.07;

  if (!st.isJumping && (st.baseline - currentY) > threshold) {
    st.isJumping = true;
  }

  if (st.isJumping && (st.baseline - currentY) < threshold * 0.7) {
    st.isJumping = false;
    st.jumps++;
    st.baseline = st.baseline * 0.9 + currentY * 0.1;
  }
}

// 工具函数
function getBodyCenter(landmarks) {
  return (landmarks[11].y + landmarks[12].y + landmarks[23].y + landmarks[24].y) / 4;
}

function getBodyHeight(landmarks) {
  return Math.abs(landmarks[11].y - landmarks[23].y);
}

function handleError(e) {
  console.error('检测错误:', e);
  if (e.message.includes('timestamp')) {
    lastTimestamp = performance.now(); // 重置时间戳
  }
}

/**
 * 注册阶段逻辑（已按最新需求修正）
 *
 * 1. 持续检测框内是否有人 (hasPerson)。
 * 2. 有人时检测举手动作 (isPrepared)，持续3秒则完成注册 (isLocked=true)。
 * 3. 倒计时逻辑：
 * - 当有玩家注册成功，且无其他玩家正在准备时 -> 启动5秒倒计时 (gameStarting=true)。
 * - 如果倒计时期间，有另一名玩家开始举手准备 -> 立刻停止倒计时 (gameStarting=false)，等待其完成注册。
 * - 当所有举手的玩家都完成注册后 -> 重新启动5秒倒计时。
 * - 倒计时结束 -> 进入执行阶段。
 */
function registrationPhase() {
  const timestamp = generateTimestamp();
  if (state.phaseStartTime === 0) {
    state.phaseStartTime = timestamp;
  }
  //更新每个玩家的独立状态（是否有人、是否准备、是否锁定）
  ['left', 'right'].forEach(side => {
    const st = state[side];
    st.hasPerson = !!st.pose; // 规则1：持续检测是否有人

    // 如果框内无人，则处理离开逻辑
    if (!st.hasPerson) {
      // 如果离开的玩家是已锁定的，这会影响全局状态，在下方统一处理
      if (st.isLocked) {
        console.log(`玩家 '${side}' 已锁定但离开。`);
        st.isLocked = false;
      }
      // 重置该玩家的准备状态
      st.isPrepared = false;
      st.prepareStartTime = null;
      return; // 继续处理另一位玩家
    }

    // 如果玩家已锁定，则无需再进行举手检测
    if (st.isLocked) {
      return;
    }

    // 检测举手动作
    const [lWrist, rWrist] = [st.pose[15], st.pose[16]];
    const [lShoulder, rShoulder] = [st.pose[11], st.pose[12]];
    const isHandRaised = (lShoulder.y - lWrist.y > 0.15) || (rShoulder.y - rWrist.y > 0.15);

    if (isHandRaised) {
      st.isPrepared = true; // 标记为正在准备
      if (!st.prepareStartTime) {
        st.prepareStartTime = timestamp; // 记录准备开始时间
      }
      // 规则2：检查是否持续举手3秒
      if (timestamp - st.prepareStartTime >= CONFIG.GAME.PLAYER_ANIMATION_DURATION) {
        st.isLocked = true; // 完成注册，标记为已锁定
        initBaseline(st);
        console.log(`玩家 '${side}' 已锁定!`);
        triggerFaceRecognition(side);
      }
    } else {
      // 如果手放下，则重置准备状态
      st.isPrepared = false;
      st.prepareStartTime = null;
    }
  });

  // 根据所有玩家的组合状态，管理全局游戏进程（倒计时）
  
  // 为了方便判断，获取双方玩家的状态
  const left = state.left;
  const right = state.right;

  // 计算当前已锁定和正在准备的玩家数量
  const lockedCount = (left.isLocked ? 1 : 0) + (right.isLocked ? 1 : 0);
  const preparingCount = ((left.isPrepared && !left.isLocked) ? 1 : 0) + ((right.isPrepared && !right.isLocked) ? 1 : 0);

  // 规则3.■：如果倒计时正在进行，但有其他玩家开始准备（举手），则立刻停止倒计时
  // 这是解决“竞速条件”的关键逻辑
  if (state.gameStarting && preparingCount > 0) {
    // console.log("检测到有新玩家正在准备，已暂停倒计时！");
    state.gameStarting = false; // 停止倒计时
    state.countdownStart = null;
  }

  // 规则3：当有玩家锁定，且【无人】正在准备时，启动或重启5秒倒计时
  // 这个条件确保了只有在所有人都“就位”后，倒计时才会开始
  if (lockedCount > 0 && preparingCount === 0 && !state.gameStarting) {
    // console.log(`已有 ${lockedCount} 名玩家锁定，且无人准备中，启动/重启 5 秒倒计时！`);
    state.gameStarting = true;
    state.countdownStart = timestamp;
  }
  
  // 如果有锁定的玩家离开，也需要停止倒计时
  if (state.gameStarting && lockedCount === 0) {
    // console.log("所有已锁定的玩家都已离开，终止倒计时。");
    state.gameStarting = false;
    state.countdownStart = null;
  }

  // 如果倒计时正在进行，则计算剩余时间
  if (state.gameStarting) {
    const elapsed = timestamp - state.countdownStart;
    if (elapsed >= CONFIG.GAME.GAME_ANIMATION_DURATION) {
      // console.log("倒计时结束，进入游戏阶段！");
      state.phase = 'playing';
      state.phaseStartTime = timestamp;
    }
  }
}

/**
 * 执行阶段（playingPhase）：
 *  - 只处理注册完成(isLocked)的选手
 *  - 调用 detectJump(st) 实现跳跃识别和计数
 *  - 当阶段时长耗尽，进入结算阶段
 */
function playingPhase() {
  const timestamp = generateTimestamp();
  ['left', 'right'].forEach(side => {
    const st = state[side];
    if (!st.isLocked || !st.pose) return; // 未注册或无姿态则跳过
    // 调用封装的跳跃检测函数
    detectJump(st);
  });

  // 判断执行阶段时长，完成后进入结算
  if (timestamp - state.phaseStartTime >= CONFIG.GAME.PLAY_DURATION) {
    state.phase = 'ended';
    state.endedStartTime = timestamp;
    state.gameEnded = true;
  }
}

/**
 * 结算阶段（endedPhase）：
 *  1. 缓冲 5 秒（gameEnded=true, gameResult=false）
 *  2. 结算页面显示 20 秒（gameEnded=true, gameResult=true）
 *  3. 自动重置，进入注册阶段，reset 所有状态
 */
function endedPhase() {
  const timestamp = generateTimestamp();
  const elapsed = timestamp - state.endedStartTime;
  const buffer = CONFIG.GAME.BUFFER_DURATION;          // 动态缓冲时长
  const settlement = CONFIG.GAME.SETTLEMENT_COUNTDOWN;// 动态显示时长

  console.log('[endedPhase]', elapsed, buffer, settlement);
  if (elapsed < buffer) {
    // 缓冲阶段
    state.gameEnded = true;
    state.gameResult = false;
    state.gameStarting    = false;
  } else if (elapsed < settlement + buffer) {
    // 结算显示阶段
    state.gameEnded = true;
    state.gameResult = true;
  } else {
    // 重置至注册阶段
    state.phase = 'registration';
    state.phaseStartTime = timestamp;
    state.gameEnded = false;
    state.gameResult = false;
    state.gameStarting = false;    
    state.countdownStart = null;    
    ['left', 'right'].forEach(side => {
      const st = state[side];
      st.isLocked = false;
      st.lockProgress = 0;
      st.isPrepared = false;
      st.hasPerson = false;
      st.jumps = 0;
      st.isJumping = false;
      st.baseline = 0;
      st.pose = null;
    });
  }
}

/**
 * 纯人脸登录功能（与特征提取完全解耦）
 * @param {Array} faceFeature - 人脸特征数组(从其他接口获得)
 * @returns {Promise<Object>} - 返回接口原始响应
 */
async function faceLogin(faceFeature) {
  if (!Array.isArray(faceFeature) || faceFeature.length === 0) {
    return {
      code: 400,
      message: "无效的人脸特征数据"
    };
  }

  try {
    const response = await fetch("http://10.1.20.216:8080/auth/login/face", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        faceFeature: faceFeature // 确保字段名与后台一致
      }),
    });

    // 直接返回原始响应，不处理业务逻辑
    return await response.json();
  } catch (error) {
    console.error("[人脸登录] 网络请求异常:", error);
    return {
      code: 500,
      message: "网络连接失败"
    };
  }
}
/**
 * side: 'left' 或 'right'
 * 你可以根据 side 去从离屏 Canvas 上裁剪对应区域的 JPEG，再发给后端识别
 */
function triggerFaceRecognition(side) {
  // 先在主 canvas 上截取对应 ROI 区域
  const roi = CONFIG.ROI[side.toUpperCase()];
  const sx = canvas.width * roi.left;
  const sy = canvas.height * roi.top;
  const sw = canvas.width * (roi.right - roi.left);
  const sh = canvas.height * (roi.bottom - roi.top);
  
  if (sw <= 0 || sh <= 0) {
    console.error(`人脸识别裁剪区域无效：sw=${sw}, sh=${sh}`);
    return;
  }

  // 创建一个临时离屏 canvas
  const temp = document.createElement('canvas');
  temp.width = sw;
  temp.height = sh;
  const tctx = temp.getContext('2d');

  // 把当前主视频帧的 ROI 部分绘制到这个离屏
  tctx.drawImage(video, sx, sy, sw, sh, 0, 0, sw, sh);

  // 转 Base64、调用接口
  const faceImage = temp.toDataURL('image/jpeg', 0.8);
  fetch('http://10.1.20.203:9000/extract', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ side, image: faceImage })
  })
    .then(r => r.json())
    .then(res => {
      console.log(`人脸识别 (${side}) 返回：`, res);
      // TODO: 根据返回结果做后续处理
      faceLogin(res.embedding)
        .then(loginResult => {
          console.log("登录结果:", loginResult);
          // 这里处理登录成功/失败逻辑
        })
        .catch(error => {
          console.error("登录流程异常:", error);
        });
    })
    .catch(err => console.error('人脸识别接口调用失败：', err));
}

//传输数据给flutter部分
setInterval(() => {
  const msg = {
    hasPerson1:    state.left.hasPerson,
    isPrepared1:   state.left.isPrepared,
    isLocked1:     state.left.isLocked,
    jumpCount1:    state.left.jumps,

    hasPerson2:    state.right.hasPerson,
    isPrepared2:   state.right.isPrepared,
    isLocked2:     state.right.isLocked,
    jumpCount2:    state.right.jumps,

    gameStarting:      state.gameStarting,
    phaseStartTimestamp: state.phaseStartTime,
    gameEnded:         state.gameEnded,
    gameResult:        state.gameResult
  };
  window.parent.postMessage(JSON.stringify(msg), '*');
}, 200);

window.addEventListener('message', (event) => {
  try {
    const data = JSON.parse(event.data);

    // 左侧面板
    document.getElementById('leftDebugPanel').innerHTML = `
      <strong>👤 人物1</strong><br>
      是否检测到：${data.hasPerson1}<br>
      是否准备好：${data.isPrepared1}<br>
      是否锁定：${data.isLocked1}<br>
      跳跃计数：${data.jumpCount1}<br>
    `;

    // 右侧面板
    document.getElementById('rightDebugPanel').innerHTML = `
      <strong>👤 人物2</strong><br>
      是否检测到：${data.hasPerson2}<br>
      是否准备好：${data.isPrepared2}<br>
      是否锁定：${data.isLocked2}<br>
      跳跃计数：${data.jumpCount2}<br>
      <hr>
      <strong>🎮 游戏状态</strong><br>
      当前阶段：${state.phase}<br>
      倒计时开始（注册完成）：${data.gameStarting}<br>
      是否结束（结算）：${data.gameEnded}<br>
      结算结果：${data.gameResult}<br>
      <hr>
      <strong>⚙️ 当前配置</strong><br>
      玩家动画时长：${CONFIG.GAME.PLAYER_ANIMATION_DURATION} ms<br>
      准备倒计时：${CONFIG.GAME.GAME_ANIMATION_DURATION} ms<br>
      游戏时长：${CONFIG.GAME.PLAY_DURATION} ms<br>
      缓冲时长：${CONFIG.GAME.BUFFER_DURATION} ms<br>
      结算倒计时：${CONFIG.GAME.SETTLEMENT_COUNTDOWN} ms<br>
    `;
  } catch (e) {
    console.warn('调试信息解析失败', e);
  }
});