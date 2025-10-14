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
    PLAYER_ANIMATION_DURATION: undefined,
    GAME_ANIMATION_DURATION: undefined,
    PLAY_DURATION: undefined,
    BUFFER_DURATION: undefined,
    SETTLEMENT_COUNTDOWN: undefined,
  },
  MIRROR_INPUT: true
};

const mapSideToRoiKey = (side) =>
  CONFIG.MIRROR_INPUT ? (side === 'left' ? 'RIGHT' : 'LEFT') : side.toUpperCase();

const API = {
  FACE_EXTRACT: 'http://10.1.20.203:9000/extract',     
  FACE_LOGIN:   'http://10.1.20.203:15005/auth/login/face',
  FACE_LOGIN_CLIENT: 'http://10.1.20.203:15005/auth/login/face/clientside',
  ADD_RECORD:   'http://10.1.20.203:15005/api/add',     
  JWT_TOKEN:    null          
};

// 状态管理
const state = {
  left: {
    pose: null, 
    baseline: 0,
    jumps: 0, 
    isLocked: false,
    lockProgress: 0, 
    hasPerson: false, 
    isPrepared: false, 
    isJumping: false , 
    userId: null, 
    username:null, 
    jwtToken: null,
    justLanded: false,
    wasPresent: false,
  },
  right: { 
    pose: null, 
    baseline: 0, 
    jumps: 0, 
    isLocked: false, 
    lockProgress: 0, 
    hasPerson: false, 
    isPrepared: false, 
    isJumping: false, 
    userId: null, 
    username:null , 
    jwtToken: null,
    justLanded: false,
    wasPresent: false,
  },
  phase: 'registration',     // 当前游戏阶段：registration, playing, ended
  phaseStartTime: 0,         // 阶段开始时间戳
  gameStarting: false,       // 是否已启动倒计时
  countdownStart: null,      // 倒计时开始时间戳
  gameEnded: false,          // gameEnded 标志
  gameResult: false ,         // 结算结果阶段标志
  endedStartTime  : 0,       // 结算阶段开始时间戳
  settlementStartTimeISO: null   //记录结算上报的 startTime ISO，以保证两侧一致且仅上报一次
};

let video = null;
let canvas = null;
let poseLeft = null;
let ctx = null;
let poseRight = null;
let offLeft = null, offRight = null;
let offCtxL = null, offCtxR = null;
let lastTimestamp = 0;

let ORIGINAL_ROI = null;      // 保存进入 playing 前的原始 ROI（按比例）
state.roiLocked = false;      // true 表示 playing 阶段保护 top/bottom 不被外部覆盖
state.pendingROI = null;      // 在 locked 时缓存外部更新，ended 时应用

function deepCopy(obj) {
  return JSON.parse(JSON.stringify(obj));
}

function recreateOffscreenCanvases() {
  if (!video) return;
  const make = (roi) => {
    const c = document.createElement('canvas');
    const w = Math.max(1, Math.round(video.videoWidth  * (roi.right - roi.left)));
    const h = Math.max(1, Math.round(video.videoHeight * (roi.bottom - roi.top)));
    c.width = w;
    c.height = h;
    return c;
  };
  offLeft  = make(CONFIG.ROI.LEFT);
  offRight = make(CONFIG.ROI.RIGHT);
  offCtxL = offLeft.getContext('2d');
  offCtxR = offRight.getContext('2d');
}

function applyFullHeightROI() {
  // 第一次进入 playing 时保存原始值
  if (!ORIGINAL_ROI) ORIGINAL_ROI = deepCopy(CONFIG.ROI);

  // 设置上下占满
  CONFIG.ROI.LEFT.top    = 0;
  CONFIG.ROI.LEFT.bottom = 1;
  CONFIG.ROI.RIGHT.top   = 0;
  CONFIG.ROI.RIGHT.bottom= 1;

  // 重建离屏 canvas 以匹配新 ROI
  recreateOffscreenCanvases();

  // 上锁：在 playing 期间保护 top/bottom 不被外部覆盖
  state.roiLocked = true;

  console.log('[ROI] applyFullHeightROI -> 全高，已上锁');
}

function setAuthToken(token) {
  API.JWT_TOKEN = token || null;
}
window.setAuthToken = setAuthToken;

function updateGameConfig(jsonStringConfig) {
  console.log('⚙️ 收到外部配置原始字符串：', jsonStringConfig);
  try {
    const externalConfig = JSON.parse(jsonStringConfig); // 解析 JSON 字符串

    CONFIG.GAME.PLAYER_ANIMATION_DURATION = externalConfig.playerAnimationDuration ?? CONFIG.GAME.PLAYER_ANIMATION_DURATION;
    CONFIG.GAME.GAME_ANIMATION_DURATION   = externalConfig.gameAnimationDuration   ?? CONFIG.GAME.GAME_ANIMATION_DURATION;
    CONFIG.GAME.PLAY_DURATION             = externalConfig.gameplayDuration        ?? CONFIG.GAME.PLAY_DURATION;
    CONFIG.GAME.BUFFER_DURATION           = externalConfig.bufferDuration          ?? CONFIG.GAME.BUFFER_DURATION;
    CONFIG.GAME.SETTLEMENT_COUNTDOWN      = externalConfig.settlementCountdown     ?? CONFIG.GAME.SETTLEMENT_COUNTDOWN;

    if (externalConfig.roi1 || externalConfig.roi2) {
      const applyROI = (src, dst) => {
        if (!src) return;
        // 始终允许水平/颜色调整（left/right/color）
        if (typeof src.left === 'number')  dst.left = src.left;
        if (typeof src.right === 'number') dst.right = src.right;
        if (typeof src.color === 'string') dst.color = src.color;

        // top/bottom 只有在未锁定时才应用
        if (!state.roiLocked) {
          if (typeof src.top === 'number')    dst.top = src.top;
          if (typeof src.bottom === 'number') dst.bottom = src.bottom;
        } else {
          // playing 期间：将外部 roi 缓存为 pending（用于 ended 后应用）
          state.pendingROI = state.pendingROI || {};
          // 以 roi1/roi2 键保存（与原外部命名一致，便于 later 合并）
          if (src === externalConfig.roi1) state.pendingROI.roi1 = deepCopy(src);
          if (src === externalConfig.roi2) state.pendingROI.roi2 = deepCopy(src);
        }
      };

      applyROI(externalConfig.roi1, CONFIG.ROI.LEFT);
      applyROI(externalConfig.roi2, CONFIG.ROI.RIGHT);

      // 如果我们刚刚更新了 CONFIG.ROI（并且未锁定），需要重建离屏 canvas
      if (!state.roiLocked) recreateOffscreenCanvases();
    }

    // 如果当前没有上锁，外部配置变更应更新 ORIGINAL_ROI（保持同步，方案B）
    if (!state.roiLocked) {
      ORIGINAL_ROI = deepCopy(CONFIG.ROI);
    }

    if (typeof externalConfig.addRecordUrl === 'string') {
      API.ADD_RECORD = externalConfig.addRecordUrl;
    }
    if (typeof externalConfig.jwtToken === 'string') {
      API.JWT_TOKEN = externalConfig.jwtToken;
    }

    console.log('⚙️ CONFIG 更新后：', CONFIG);
   } catch (e) {
    console.error('❌ 解析外部配置失败：', e, '接收到的字符串：', jsonStringConfig);
   }
}
window.updateGameConfig = updateGameConfig; // This makes it globally accessible

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
      // 在 canvas.width/height 设置完后（video.readyState >=2 or loadeddata 回调内）
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;

      // 保存原始 ROI（按比例）—— 方案B 的关键
      if (!ORIGINAL_ROI) ORIGINAL_ROI = deepCopy(CONFIG.ROI);

      // 根据 CONFIG.ROI 创建离屏 canvas（使用统一函数）
      recreateOffscreenCanvases();

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
    processROI('left',  offLeft,  offCtxL, CONFIG.ROI[mapSideToRoiKey('left')],  timestamp),
  processROI('right', offRight, offCtxR, CONFIG.ROI[mapSideToRoiKey('right')], timestamp)
  ]).then(() => {
    requestAnimationFrame(processFrame);
  }).catch(handleError);
}

function generateTimestamp() {
  const now = performance.now();
  lastTimestamp = now > lastTimestamp ? now : lastTimestamp + 1;
  return lastTimestamp;
}


async function processROI(side, offCanvas, offCtx, roi, timestamp) {

  // 裁剪区域
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

   if (result.landmarks.length > 0  && isBigEnough(result.landmarks[0])) {
    updateState(side, result.landmarks[0], x, y);
  }else {
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
  const height = yBot - yTop;      // 归一化高度
  return height > 0.15;             // 阈值可根据场景调整
}


function updateState(side, landmarks, offsetX, offsetY) {
  const st = state[side];

  // 选择对应的离屏 canvas（修复 bug）
  const off = side === 'left' ? offLeft : offRight;

  // 坐标转换：将局部 offCanvas 的归一化坐标映射到全画布归一化坐标
  const converted = landmarks.map(pt => ({
    x: (pt.x * off.width + offsetX) / canvas.width,      // 全局归一化 x
    y: (pt.y * off.height + offsetY) / canvas.height,    // 全局归一化 y（**关键**）
    z: pt.z
  }));

  // 平滑处理（保持原逻辑）
  st.pose = st.pose ? converted.map((lm, i) => ({
    x: lm.x * 0.3 + st.pose[i].x * 0.7,
    y: lm.y * 0.3 + st.pose[i].y * 0.7,
    z: lm.z * 0.3 + st.pose[i].z * 0.7
  })) : converted;

  if (state.phase === 'playing' && state.recording) {
    const recordFrame = {
      t: lastTimestamp,        
      frameIndex: (state.recordings[side].length || 0),
      landmarks: converted.map(p => ({ x: p.x, y: p.y, z: p.z })) 
    };
    state.recordings[side].push(recordFrame);
  }
}



function initBaseline(st) {
  const keyPoints = [11, 12, 23, 24];
  st.baseline = keyPoints.reduce((s, i) => s + st.pose[i].y, 0) / keyPoints.length;
}

function detectJump(st) {
  const currentY = getBodyCenter(st.pose);
  const threshold = getBodyHeight(st.pose) * 0.07;

  st.justLanded = false;

  if (!st.isJumping && (st.baseline - currentY) > threshold) {
    st.isJumping = true;
  }
  else if (st.isJumping && (st.baseline - currentY) < threshold * 0.7) {
    st.isJumping = false;
    st.jumps++;
    st.justLanded = true; 

    if (st.justLanded) {
      const landingAlpha = 0.25;
      st.baseline = st.baseline * (1 - landingAlpha) + currentY * landingAlpha;
    } 
    else if (!st.isJumping) {
      const standingAlpha = 0.005; 
      st.baseline = st.baseline * (1 - standingAlpha) + currentY * standingAlpha;
    }
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

        const hadIdentity = st.username != null || st.userId != null;
        st.userId = null;
        st.username = null;

        if (hadIdentity) {
          window.parent.postMessage(JSON.stringify({
            type: 'faceClear',
            side
          }), '*');
          // console.log('[JS→Flutter] faceClear 发送：', { side });
        }
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

      if (!ORIGINAL_ROI) ORIGINAL_ROI = deepCopy(CONFIG.ROI);

      // 将 ROI 设置为上下全高并上锁
      applyFullHeightROI();
      // console.log("倒计时结束，进入游戏阶段！");
      state.phase = 'playing';
      state.phaseStartTime = timestamp;
    }
  }
}

/**
 * 执行阶段（playingPhase）：
 *  - 只处理注册完成(isLocked)的选手
 *  - 调用 detectJump(st) 实现跳跃识别和计数
 *  - 当阶段时长耗尽，进入结算阶段
 */
function playingPhase() {
  const timestamp = generateTimestamp();

  if (!state.recording) {
    startRecording();
  }

  ['left', 'right'].forEach(side => {
    const st = state[side];
    const isPresent = !!st.pose;

    if (isPresent) {
      // 玩家在场
      if (!st.wasPresent) {
        initBaseline(st);   
        st.isJumping = false; 
      }
    } else {
      // 玩家不在场
      if (st.wasPresent) {
        st.isJumping = false; 
      }
    }

    // 只有当玩家锁定且在场时，才执行跳跃检测
    if (st.isLocked && isPresent) {
      detectJump(st);
    }

    // 在每一帧的最后，更新“上一帧的状态”，为下一帧的比较做准备
    st.wasPresent = isPresent;
  });

  // 判断执行阶段时长，完成后进入结算
  if (timestamp - state.phaseStartTime >= CONFIG.GAME.PLAY_DURATION) {
    
    state.phase = 'ended';
    state.endedStartTime = timestamp;
    state.gameEnded = true;

    // 上报左右两名已识别用户的运动记录
    state.settlementStartTimeISO = new Date().toISOString();
    submitSportRecordsForBothSides(state.settlementStartTimeISO)
      .then((results) => {
        console.log('[submitSportRecordsForBothSides] done', results);
        // 上传完成后再停止记录并清空内存
        stopRecordingAndSave();
      })
      .catch((err) => {
        console.error('[submitSportRecordsForBothSides] error', err);
        // 即便上传失败也调用停止与清理（上层宿主会有失败通知，可安排重试）
        stopRecordingAndSave();
      });
  }
}

/**
 * 结算阶段（endedPhase）：
 *  1. 缓冲 5 秒（gameEnded=true, gameResult=false）
 *  2. 结算页面显示 20 秒（gameEnded=true, gameResult=true）
 *  3. 自动重置，进入注册阶段，reset 所有状态
 */
function endedPhase() {
  const timestamp = generateTimestamp();
  const elapsed = timestamp - state.endedStartTime;
  const buffer = CONFIG.GAME.BUFFER_DURATION;          // 动态缓冲时长
  const settlement = CONFIG.GAME.SETTLEMENT_COUNTDOWN;// 动态显示时长

  console.log('[endedPhase]', elapsed, buffer, settlement);
  if (elapsed < buffer) {
    // 缓冲阶段
    state.gameEnded = true;
    state.gameResult = false;
    state.gameStarting    = false;
  } else if (elapsed < settlement + buffer) {
    // 结算显示阶段
    state.gameEnded = true;
    state.gameResult = true;
  } else {
      if (state.pendingROI) {
      // 先把 ORIGINAL_ROI 恢复到 CONFIG（相当于 restore，但不改变 roiLocked）
      Object.assign(CONFIG.ROI.LEFT,  ORIGINAL_ROI.LEFT);
      Object.assign(CONFIG.ROI.RIGHT, ORIGINAL_ROI.RIGHT);

      // 再把 pending 覆盖上去（只会包含外部想修改的字段）
      if (state.pendingROI.roi1) Object.assign(CONFIG.ROI.LEFT,  state.pendingROI.roi1);
      if (state.pendingROI.roi2) Object.assign(CONFIG.ROI.RIGHT, state.pendingROI.roi2);

      // 清理 pending 并更新 ORIGINAL_ROI 与离屏 canvas
      state.pendingROI = null;
      ORIGINAL_ROI = deepCopy(CONFIG.ROI);
      recreateOffscreenCanvases();

      // 最后统一解锁（保证在整个应用流程中没有短暂解锁窗口）
      state.roiLocked = false;

      console.log('[ROI] 已应用 pendingROI（在 ended/reset 时）');
    }

    // 重置至注册阶段
    state.phase = 'registration';
    state.phaseStartTime = timestamp;
    state.gameEnded = false;
    state.gameResult = false;
    state.gameStarting = false;    
    state.countdownStart = null;   
    state.settlementStartTimeISO = null; 
    
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
      st.userId = null;
      st.username = null;
      st.jwtToken = null;
      st.justLanded = false;
      st.wasPresent = false;

      window.parent.postMessage(JSON.stringify({ type: 'faceClear', side }), '*');
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
    return { code: 400, message: "无效的人脸特征数据" };
  }

  const tryLogin = async (url) => {
    const resp = await fetch(url, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ faceFeature })
    });
    const json = await resp.json().catch(() => ({}));
    return { resp, json };
  };

  // 1) 先尝试正式登录（匹配现有用户）
  try {
    let { json } = await tryLogin(API.FACE_LOGIN);
    const data = json?.data ?? json;
    const matched =
      json?.code === 200 &&
      (!!data?.userId || !!data?.userID || !!data?.id || !!data?.userInfo?.userId);

    if (matched) return json;

    // 2) 未匹配到 -> 游客自动注册并登录
    ({ json } = await tryLogin(API.FACE_LOGIN_CLIENT));
    return json;
  } catch (err1) {
    console.warn("[faceLogin] 正式登录异常，尝试游客登录：", err1);
    try {
      const { json } = await tryLogin(API.FACE_LOGIN_CLIENT);
      return json;
    } catch (err2) {
      console.error("[faceLogin] 游客登录也失败：", err2);
      return { code: 500, message: "网络连接失败" };
    }
  }
}
/**
 * side: 'left' 或 'right'
 * 你可以根据 side 去从离屏 Canvas 上裁剪对应区域的 JPEG，再发给后端识别
 */
function triggerFaceRecognition(side) {
  // 1) 先裁剪 ROI
  const roi = CONFIG.ROI[mapSideToRoiKey(side)];
  const sx = video.videoWidth  * roi.left;
  const sy = video.videoHeight * roi.top;
  const sw = video.videoWidth  * (roi.right - roi.left);
  const sh = video.videoHeight * (roi.bottom - roi.top);

  if (sw <= 0 || sh <= 0) {
    console.warn(`[${side}] ROI 尺寸无效，跳过人脸识别`, roi);
    return;
  }

  const temp = document.createElement('canvas');
  temp.width = sw;
  temp.height = sh;
  const tctx = temp.getContext('2d');
  tctx.drawImage(video, sx, sy, sw, sh, 0, 0, sw, sh);

  const faceImage = temp.toDataURL('image/jpeg', 0.8);

  const url = API.FACE_EXTRACT;
  fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ side, image: faceImage })
  })
  .then(r => r.json())
  .then(res => {
    console.log(`人脸识别 (${side}) 返回：`, res);

    const embedding = res?.data?.embedding ?? res?.embedding ?? null;
    if (!Array.isArray(embedding) || embedding.length === 0) {
      console.warn(`[${side}] 提取服务未返回有效 embedding:`, res);
      return; // 直接结束；也可以在这里安排下一次尝试
    }

    return faceLogin(embedding);
  })
  .then(loginResult => {
    if (!loginResult) return; // 上一步就失败了

    console.log("登录结果:", loginResult);
    const data = loginResult?.data ?? loginResult;

    if (loginResult?.code && loginResult.code !== 200) {
      console.warn(`[${side}] 登录失败 code=${loginResult.code} msg=${loginResult.message}`);
      return;
    }

    const st = state[side];
    const userInfo = data?.userInfo ?? data;     // 兼容游客返回(data.userInfo)与正式返回(data)
    st.userId   = userInfo?.userId   ?? userInfo?.userID ?? userInfo?.id ?? null;
    st.username = userInfo?.username ?? userInfo?.realname ?? st.userId ?? null;
    st.jwtToken = data?.token ?? null;           // token 在 data.token
    const isGuest = userInfo?.isGuest ?? false;

    // 发给 Flutter
    window.parent.postMessage(JSON.stringify({
      type: 'faceLogin',
      side,
      userId:   st.userId,
      username: st.username,
      isGuest
    }), '*');
  })
  .catch(err => {
    console.error(`[${side}] 人脸识别接口调用失败:`, { url, err });

    const st = state[side];
    if (st?.isLocked) {
      setTimeout(() => {
        if (st.isLocked) triggerFaceRecognition(side);
      }, 1500);
    }
  });
}

//上报运动记录
function submitSportRecordsForBothSides(startTimeISO) {
  const promises = ['left', 'right'].map(side => {
    const st = state[side];
    if (!st?.userId) {
      console.log(`[addRecord] ${side}: userId 为空，跳过上报。`);
      return Promise.resolve({ skipped: true, side });
    }
    return addSportRecord({
      side,
      userId: st.userId,
      count: st.jumps,
      startTimeISO,
      tokenForSide: st.jwtToken || API.JWT_TOKEN || null
    });
  });
  // 返回 Promise，在调用处用 .then/.catch 等待完成
  return Promise.all(promises);
}

async function addSportRecord({ side, userId, count, startTimeISO, tokenForSide }) {
  const url = API.ADD_RECORD;

  // duration 单位为秒；若没配置 PLAY_DURATION，尝试根据 recording 时间计算
  let durationToSend = Math.round((CONFIG.GAME.PLAY_DURATION ?? 0) / 1000);
  if ((!CONFIG.GAME.PLAY_DURATION || CONFIG.GAME.PLAY_DURATION === 0) && state.recordingStartISO) {
    // 尝试从 recordingStartISO 计算时长（防止未设置 CONFIG）
    const startMs = Date.parse(state.recordingStartISO) || Date.now();
    const nowMs = Date.now();
    durationToSend = Math.max(0, Math.round((nowMs - startMs) / 1000));
  }

  // 准备 NDJSON 字符串（每帧一行 JSON）
  const frames = state.recordings[side] || [];
  const ndjson = frames.length ? frames.map(f => JSON.stringify(f)).join('\n') : '';

  // 构造 FormData
  const formData = new FormData();
  formData.append('sportType', 'rope_skipping'); // 按需求可替换为 jumping_jacks 等
  formData.append('count', String(count ?? 0));
  // API 接受 ISO 字符串或时间戳，这里传 ISO
  formData.append('startTime', startTimeISO || new Date().toISOString());
  formData.append('duration', String(durationToSend));

  // poseDataFile 必填：若没有帧，仍上传一个空文件（服务端若要求非空，可按需修改）
  const filenameSafe = `pose_${side}_${(state.recordingStartISO || new Date().toISOString()).replace(/[:.]/g,'-')}.ndjson`;
  const poseBlob = new Blob([ndjson], { type: 'application/x-ndjson' });
  formData.append('poseDataFile', poseBlob, filenameSafe);

  // 准备 headers（不要手动设置 Content-Type，否则 boundary 会丢失）
  const headers = {};
  const token = tokenForSide || null;
  if (token) headers['Authorization'] = `Bearer ${token}`;
  else console.warn('[addRecord] 未设置 JWT，将不带 Authorization 头。');

  try {
    console.log(`[addRecord] 上传 ${side} poseData (${frames.length} frames) -> ${url}`);

    const resp = await fetch(url, {
      method: 'POST',
      headers, // 只携带 Authorization（若有），FormData 会自动设置 Content-Type
      body: formData,
      // keepalive 可在页面卸载时尝试完成，但对大文件无效且浏览器对长度有限制
      // keepalive: true
    });

    const json = await resp.json().catch(() => ({}));
    const ok = resp.ok && (json?.code === 201 || json?.success === true || json?.code === 200);

    console.log(`[addRecord] ${side} status=${resp.status}`, json);

    // 通知宿主（Flutter / 上层容器） —— 保持原来消息结构
    window.parent.postMessage(JSON.stringify({
      type: 'sportRecord',
      side,
      request: {
        userId,
        sportType: 'rope_skipping',
        count,
        startTime: startTimeISO,
        duration: durationToSend,
        poseFile: filenameSafe,
        framesSent: frames.length
      },
      response: json,
      httpStatus: resp.status,
      success: ok
    }), '*');

    // 若上传成功，清空该侧记录以释放内存
    if (ok) {
      state.recordings[side] = [];
      console.log(`[addRecord] ${side} recordings cleared after successful upload.`);
    } else {
      console.warn(`[addRecord] ${side} upload returned non-OK response. recordings kept for retry.`);
    }

    return json;
  } catch (err) {
    console.error(`[addRecord] ${side} 调用失败:`, { url, err, payload: { userId, count, startTimeISO }});
    // 通知宿主上传失败（便于宿主端重试或提示）
    window.parent.postMessage(JSON.stringify({
      type: 'sportRecord',
      side,
      request: { userId, sportType: 'rope_skipping', count, startTime: startTimeISO },
      error: String(err),
      success: false
    }), '*');
    // 不清空 recordings（便于后续重试）
    return { code: 500, message: '网络连接失败', error: String(err) };
  }
}

state.recordings = { left: [], right: [] };   // 存放每一帧（内存中）
state.recording = false;                      // 是否正在记录
state.recordingStartISO = null;

function frameToSimpleObject(frame) {
  // frame.landmarks 是 [{x,y,z},...]（全局归一化）
  return {
    t: frame.t,            // timestamp (ms) 或 performance.now
    frameIndex: frame.frameIndex, // 可选 index
    landmarks: frame.landmarks    // array of coords
  };
}

function framesToNDJSON(frames) {
  return frames.map(f => JSON.stringify(frameToSimpleObject(f))).join('\n');
}

function framesToJSON(frames) {
  return JSON.stringify({
    meta: {
      startedAt: state.recordingStartISO,
      frameCount: frames.length,
      fpsApprox: frames.length / ((frames.length ? (frames[frames.length-1].t - frames[0].t) : 1) / 1000)
    },
    frames: frames.map(frameToSimpleObject)
  }, null, 2);
}

function framesToCSV(frames) {
  // header：t,frameIndex, l0_x,l0_y,l0_z, l1_x,...
  if (frames.length === 0) return '';
  const lmCount = frames[0].landmarks.length;
  const headers = ['t','frameIndex'];
  for (let i=0; i<lmCount; i++) {
    headers.push(`l${i}_x`, `l${i}_y`, `l${i}_z`);
  }
  const lines = [headers.join(',')];
  for (const f of frames) {
    const row = [f.t, f.frameIndex];
    for (const lm of f.landmarks) row.push(lm.x, lm.y, lm.z);
    lines.push(row.join(','));
  }
  return lines.join('\n');
}

/* ======= 开始/停止记录的控制函数 ======= */
function startRecording() {
  state.recordings = { left: [], right: [] };
  state.recording = true;
  state.recordingStartISO = new Date().toISOString();
  console.log('[Recording] started at', state.recordingStartISO);
}

function stopRecordingAndSave() {
  // 停止记录（若尚未停止）
  state.recording = false;
  const startISO = state.recordingStartISO || new Date().toISOString();

  // 不触发本地下载，改为清理内存（如果 addSportRecord 已在上传成功时清理，则此处只是保险）
  ['left','right'].forEach(side => {
    const frames = state.recordings[side] || [];
    if (!frames || frames.length === 0) {
      console.log(`[Recording] ${side} no frames or already uploaded, skip clear.`);
    } else {
      // 若 recordings 仍然存在（上传失败或未触发上传），一并清理以避免内存泄露
      console.log(`[Recording] ${side} clearing ${frames.length} frames from memory.`);
      state.recordings[side] = [];
    }
  });

  // 重置 recording 相关元数据
  state.recordingStartISO = null;
  console.log('[Recording] stopped and cleared at', new Date().toISOString());
}

//传输数据给flutter部分
setInterval(() => {
  const msg = {
    hasPerson1:    state.left.hasPerson,
    isPrepared1:   state.left.isPrepared,
    isLocked1:     state.left.isLocked,
    jumpCount1:    state.left.jumps,

    hasPerson2:    state.right.hasPerson,
    isPrepared2:   state.right.isPrepared,
    isLocked2:     state.right.isLocked,
    jumpCount2:    state.right.jumps,

    gameStarting:      state.gameStarting,
    phaseStartTimestamp: state.phaseStartTime,
    gameEnded:         state.gameEnded,
    gameResult:        state.gameResult,

    username1: state.left.username,
    username2: state.right.username,
    userId1:   state.left.userId,
    userId2:   state.right.userId,
  };
  window.parent.postMessage(JSON.stringify(msg), '*');
}, 200);

// window.addEventListener('message', (event) => {
//   try {
//     // 支持宿主发送字符串或对象
//     const data = (typeof event.data === 'string') ? JSON.parse(event.data) : event.data;

//     // 当前 ROI 信息（实时读取 CONFIG）
//     const roiLeft  = CONFIG.ROI.LEFT;
//     const roiRight = CONFIG.ROI.RIGHT;

//     // 左侧面板
//     const leftPanel = document.getElementById('leftDebugPanel');
//     if (leftPanel) {
//       leftPanel.innerHTML = `
//         <strong>👤 人物1</strong><br>
//         是否检测到：${data.hasPerson1}<br>
//         是否准备好：${data.isPrepared1}<br>
//         是否锁定：${data.isLocked1}<br>
//         跳跃计数：${data.jumpCount1}<br>
//         <hr>
//         <strong>📐 当前 ROI（Left）</strong><br>
//         left: ${roiLeft.left}, top: ${roiLeft.top}, right: ${roiLeft.right}, bottom: ${roiLeft.bottom}<br>
//         color: ${roiLeft.color}<br>
//       `;
//     }

//     // 右侧面板
//     const rightPanel = document.getElementById('rightDebugPanel');
//     if (rightPanel) {
//       rightPanel.innerHTML = `
//         <strong>👤 人物2</strong><br>
//         是否检测到：${data.hasPerson2}<br>
//         是否准备好：${data.isPrepared2}<br>
//         是否锁定：${data.isLocked2}<br>
//         跳跃计数：${data.jumpCount2}<br>
//         <hr>
//         <strong>🎮 游戏状态</strong><br>
//         当前阶段：${state.phase}<br>
//         倒计时开始（注册完成）：${data.gameStarting}<br>
//         是否结束（结算）：${data.gameEnded}<br>
//         结算结果：${data.gameResult}<br>
//         <hr>
//         <strong>📐 当前 ROI（Right）</strong><br>
//         left: ${roiRight.left}, top: ${roiRight.top}, right: ${roiRight.right}, bottom: ${roiRight.bottom}<br>
//         color: ${roiRight.color}<br>
//         <hr>
//         <strong>⚙️ 当前配置</strong><br>
//         玩家动画时长：${CONFIG.GAME.PLAYER_ANIMATION_DURATION} ms<br>
//         准备倒计时：${CONFIG.GAME.GAME_ANIMATION_DURATION} ms<br>
//         游戏时长：${CONFIG.GAME.PLAY_DURATION} ms<br>
//         缓冲时长：${CONFIG.GAME.BUFFER_DURATION} ms<br>
//         结算倒计时：${CONFIG.GAME.SETTLEMENT_COUNTDOWN} ms<br>
//       `;
//     }
//   } catch (e) {
//     console.warn('调试信息解析失败或渲染失败', e);
//   }
// });

