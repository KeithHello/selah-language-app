'use strict';

const principles = [
  ['价值后反馈', '至少完成一次核心闭环：输入真实想法、生成英文、听到音频并保存。'],
  ['微反馈先行', '单次功能结束只问 1 题；主问卷等多次使用后出现，降低打扰。'],
  ['行为决定分支', '使用频次、功能组合、卡点和当前回答共同决定下一题。'],
  ['付费引导后置', '先确认价值和阻碍，再给与场景匹配的方案解释。'],
  ['研究与权益隔离', '问卷自愿填写，不影响试用、会员或服务质量。']
];

const state = { scenarioId: 'engaged', index: 0, answers: {} };

const $ = id => document.getElementById(id);
const esc = value => String(value).replace(/[&<>"']/g, s => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[s]));

function currentScenario() {
  return scenarios.find(item => item.id === state.scenarioId) || scenarios[0];
}

function visibleSteps() {
  return currentScenario().steps.filter(step => !step.only || step.only(state.answers));
}

function renderPrinciples() {
  $('principles').innerHTML = principles.map((item, index) =>
    `<article class="mini-card"><span class="num">${index + 1}</span><div><strong>${item[0]}</strong><span>${item[1]}</span></div></article>`
  ).join('');
  $('timeline').innerHTML = moments.map(item =>
    `<article class="moment"><span class="when">${item[0]}</span><div><strong>${item[1]}</strong><p>${item[2]}</p></div></article>`
  ).join('');
}

function renderScenarioTabs() {
  $('scenarioBar').innerHTML = scenarios.map(item =>
    `<button class="scenario-btn" type="button" data-scenario="${item.id}" aria-pressed="${item.id === state.scenarioId}">${item.tab}</button>`
  ).join('');
}

function renderStats(stats) {
  return `<div class="behavior">${stats.map(item => `<div><strong>${item[0]}</strong><span>${item[1]}</span></div>`).join('')}</div>`;
}

function answerClass(step, option) {
  const answer = state.answers[step.key];
  const selected = step.type === 'multi' ? Array.isArray(answer) && answer.includes(option) : answer === option;
  return selected ? 'answer selected' : 'answer';
}

function optionTemplate(step, option) {
  const answer = state.answers[step.key];
  const checked = step.type === 'multi' ? Array.isArray(answer) && answer.includes(option) : answer === option;
  return `<button type="button" class="${answerClass(step, option)}" data-key="${step.key}" data-option="${esc(option)}"><span class="mark">${checked ? '✓' : ''}</span><span>${option}</span></button>`;
}

function renderQuestion(step, visibleIndex, total) {
  const gridClass = step.type === 'scale' ? 'answers scale' : step.type === 'single' && step.options.length > 2 ? 'answers choice-grid' : 'answers';
  const answer = state.answers[step.key];
  const canContinue = step.type === 'multi' ? Array.isArray(answer) && answer.length > 0 && (!step.max || answer.length <= step.max) : Boolean(answer);
  return `<article class="survey ${step.options.length === 6 ? 'scale-six' : ''}" aria-live="polite">
    <div class="meta"><span>${step.label}</span><div class="progress"><i style="width:${Math.round((visibleIndex + 1) / total * 100)}%"></i></div><span>${visibleIndex + 1}/${total}</span></div>
    <div class="qlabel">${step.optional ? '选答 · 不影响权益' : '匿名反馈 · 不影响权益'}</div>
    <h3 class="question">${step.q}</h3>
    ${step.help ? `<p class="help">${step.help}</p>` : ''}
    <div class="${gridClass}">${step.options.map(option => optionTemplate(step, option)).join('')}</div>
    ${step.open ? '<p class="help">选择后可在正式产品中展开一行文本框；本 Demo 用选项模拟。</p>' : ''}
    ${step.type === 'multi' && step.max ? `<p class="help">最多选择 ${step.max} 项。</p>` : ''}
    <div class="actions">
      <button type="button" class="btn text" data-action="skip">${visibleIndex === 0 ? '暂时跳过' : '上一步'} </button>
      <button type="button" class="btn primary" data-action="next" ${canContinue ? '' : 'disabled'}>下一步</button>
    </div>
    <div class="branch">系统只记录题目编号、选项、版本和触发上下文；不读取或展示你的原始句子内容。</div>
  </article>`;
}

function renderOffer() {
  const a = state.answers;
  const highValue = Number(a.valueScore) >= 4 || a.pmf === '非常失望' || a.payIntent === '肯定会' || a.payIntent === '可能会';
  const blocked = ['需要再想想','大概不会','肯定不会'].includes(a.payIntent) || (Number(a.blockedValue) && Number(a.blockedValue) <= 3) || (Array.isArray(a.blockedReason) && a.blockedReason.length > 0);
  if (state.scenarioId === 'low') {
    return `<article class="offer"><h3>先帮你完成下一次练习</h3><p>你选择了「${esc(a.helpPref || '给我 3 个可直接改写的句子')}」。低激活阶段不展示付费引导，先让用户体验第二次成功。</p><a class="btn primary full" href="#" aria-label="Demo 中不跳转">生成今天的 3 个练习起点</a><p class="fineprint">Demo 按钮不会调用模型，也不会改变权益。</p></article>`;
  }
  if (blocked) {
    const reason = a.priceBlocker || a.blockedReason || '还需要确认使用频率';
    return `<article class="offer"><h3>按你的顾虑解释方案</h3><p>你提到的主要顾虑是：<strong>${Array.isArray(reason) ? reason.join('、') : esc(reason)}</strong>。先给清晰说明，不使用限时折扣逼迫决策。</p><div class="plan"><div><strong>继续学习已有内容</strong><span>已保存句子、笔记和本机音频不受影响</span></div><span class="price">免费</span></div><div class="plan"><div><strong>月会员</strong><span>300 条表达 · 30000 配音字符 · 60 分钟转写 · 30 次整理</span></div><span class="price">¥39.9／月</span></div><p class="fineprint">主动续购，不自动扣款；正式产品中此处进入完整方案页，而不是直接付款。</p><a class="btn soft full" href="#" aria-label="Demo 中不跳转">查看完整方案说明</a></article>`;
  }
  if (highValue || state.scenarioId === 'member') {
    return `<article class="offer"><h3>${state.scenarioId === 'member' ? '感谢你这个月的练习' : '把正在形成的习惯继续下去'}</h3><p>${state.scenarioId === 'member' ? '我们会优先参考你选择的功能方向；续购入口只解释下个账期，不制造倒计时压力。' : '你已经在几天内多次使用核心闭环。这里可以自然进入完整方案页，让用户按自己的节奏决定。'}</p><div class="plan"><div><strong>月会员</strong><span>每月 300 条个人表达、30000 配音字符、60 分钟转写、30 次长文整理</span></div><span class="price">¥39.9／月</span></div><a class="btn primary full" href="#" aria-label="Demo 中不跳转">查看月会员方案</a><p class="fineprint">主动续购，不自动扣款；支付前再次展示完整权益、计量方式与 AI 说明。</p></article>`;
  }
  return `<article class="offer"><h3>反馈已记录</h3><p>当前信号不足以推荐付费方案。系统会优先把你遇到的问题分配给产品改进，而不是继续展示会员入口。</p><button class="btn soft full" type="button" data-action="restart">重新体验本场景</button></article>`;
}

function renderComplete() {
  return `<article class="survey complete"><div class="seal">✓</div><h3>谢谢你，反馈已经收下</h3><p>你的回答会与使用阶段、功能使用类型和后续行为做汇总分析；不会因为跳过或填写而改变试用或会员权益。</p><div class="actions"><button class="btn soft" type="button" data-action="restart">重新选择</button><button class="btn primary" type="button" data-action="close">回到今天</button></div></article>${renderOffer()}`;
}

function renderPhone() {
  const scenario = currentScenario();
  const steps = visibleSteps();
  $('appState').textContent = scenario.state;
  const survey = state.completed ? renderComplete() : steps[state.index] ? renderQuestion(steps[state.index], state.index, steps.length) : renderComplete();
  $('phoneScreen').innerHTML = `
    <section class="context">
      <h3>${scenario.title}</h3>
      <p>${scenario.copy}</p>
      ${renderStats(scenario.stats)}
      <p><strong>触发规则：</strong>${scenario.trigger}</p>
    </section>
    ${survey}
  `;
  renderDashboard();
}

function selectedFeatureTags() {
  const features = [].concat(state.answers.features || [], state.answers.priority || []);
  if (!features.length) return ['等待真实反馈'];
  return features;
}

function renderDashboard() {
  const a = state.answers;
  const scenario = currentScenario();
  const value = Number(a.valueScore || a.blockedValue || a.firstHelpful) || null;
  const intent = a.payIntent || a.renewal || '未询问';
  const signal = [];
  if (value) signal.push(['价值评分', value >= 4 ? '已体验到价值' : value === 3 ? '价值待确认' : '优先改进']);
  if (a.pmf) signal.push(['PMF', a.pmf]);
  if (intent) signal.push(['付费／续购意向', intent]);
  if (a.barrier) signal.push(['持续阻碍', [].concat(a.barrier).join('、')]);
  if (a.blockedReason) signal.push(['付费阻碍', [].concat(a.blockedReason).join('、')]);
  if (a.lowReason) signal.push(['低激活原因', [].concat(a.lowReason).join('、')]);
  if (a.priority) signal.push(['会员功能诉求', [].concat(a.priority).join('、')]);

  $('metrics').innerHTML = [
    ['样本阶段', scenario.tab, '按生命周期分层，不混算'],
    ['价值信号', value ? `${value}/5` : '—', value && value >= 4 ? '可进入方案解释' : '先做帮助或改进'],
    ['商业意向', intent, '需结合后续转化验证'],
    ['问卷长度', state.completed ? `${visibleSteps().length} 题已完成` : `${state.index + 1}/${visibleSteps().length}`, '按回答动态跳过']
  ].map(item => `<article class="metric"><strong>${item[1]}</strong><span>${item[0]}</span><i>${item[2]}</i></article>`).join('');

  $('liveSignal').innerHTML = signal.length ? signal.map(item =>
    `<div class="rec"><strong>${item[0]}</strong><p>${Array.isArray(item[1]) ? item[1].join('、') : item[1]}</p></div>`
  ).join('') : '<div class="rec"><p>选择左侧手机里的答案后，这里会实时显示分流信号。</p></div>';

  $('featureTags').innerHTML = selectedFeatureTags().map((tag, index) =>
    `<span class="tag ${index < 2 ? 'hot' : ''}">${tag}</span>`
  ).join('');

  $('schema').textContent = [
    'survey_response {',
    '  response_id, user_id_hashed, survey_version',
    '  trigger: moment, scenario, eligible_at, shown_at',
    '  behavior_bucket: active_days, generations, listens, reviews',
    '  answers: [{ question_id, option_id, skipped }]',
    '  branch_path: [question_id, reason]',
    '  research_consent: version, choice, consented_at',
    '  followup: offer_shown, plan_opened, checkout_started, converted_at',
    '  privacy: no raw sentence, no audio, no payment credential',
    '}'
  ].join('\n');
}

function resetRun() {
  state.index = 0;
  state.answers = {};
  state.completed = false;
  renderScenarioTabs();
  renderPhone();
}

function selectScenario(id) {
  state.scenarioId = id;
  resetRun();
}

function choose(stepKey, option, max) {
  const step = currentScenario().steps.find(item => item.key === stepKey);
  if (!step) return;
  if (step.type === 'multi') {
    const current = Array.isArray(state.answers[stepKey]) ? state.answers[stepKey] : [];
    const next = current.includes(option) ? current.filter(item => item !== option) : current.concat(option);
    if (max && next.length > max) return;
    state.answers[stepKey] = next;
  } else {
    state.answers[stepKey] = option;
  }
  renderPhone();
}

function next() {
  const steps = visibleSteps();
  const step = steps[state.index];
  if (!step) return;
  const answer = state.answers[step.key];
  const answered = step.type === 'multi' ? Array.isArray(answer) && answer.length : Boolean(answer);
  if (!answered && !step.optional) return;
  if (state.index < steps.length - 1) {
    state.index += 1;
    const phone = document.querySelector('.phone');
    phone.scrollTop = 0;
    renderPhone();
  } else {
    state.completed = true;
    renderPhone();
  }
}

function backOrSkip() {
  if (state.index > 0) {
    state.index -= 1;
    renderPhone();
  } else {
    state.skippedAtFirst = true;
    state.completed = true;
    state.answers.skipped = '首题跳过';
    renderPhone();
  }
}

document.addEventListener('click', event => {
  const scenarioButton = event.target.closest('[data-scenario]');
  if (scenarioButton) selectScenario(scenarioButton.dataset.scenario);

  const optionButton = event.target.closest('[data-option]');
  if (optionButton) {
    const max = currentScenario().steps.find(item => item.key === optionButton.dataset.key)?.max;
    choose(optionButton.dataset.key, optionButton.dataset.option, max);
  }

  const actionButton = event.target.closest('[data-action]');
  if (!actionButton) return;
  const action = actionButton.dataset.action;
  if (action === 'next') next();
  if (action === 'skip') backOrSkip();
  if (action === 'restart') resetRun();
  if (action === 'close') {
    state.completed = true;
    state.answers.closed = '回到今天';
    renderPhone();
  }
});

const moments = [
  ['T+0', '一次音频播放或复习完成后', '只问 1 题即时满意度，延迟 8—15 秒或回到句子页时出现。'],
  ['48h', '至少 2 个活跃日之后', '若已生成 3 条以上个人表达，邀请 2—4 题主问卷。'],
  ['D3—D5', '多次体验核心价值时', '询问 PMF、最常用功能和持续使用阻碍；高意向才解释会员。'],
  ['受限', '用户触发生成受限后', '先说明原因与可继续使用的功能，再在非阻断卡片中问阻碍。'],
  ['D6', '试用期末但未高频使用', '不问价格，先识别激活问题、使用场景和提醒偏好。'],
  ['D24', '会员账期结束前', '问成果、NPS、功能优先级和续购信心，不制造倒计时焦虑。']
];

const scenarios = [
  {
    id: 'activated',
    tab: '刚激活',
    state: '第一条个人表达已保存',
    title: '第一次听到自己的英文',
    copy: '系统确认句子与音频都已保存。此时用户刚完成核心闭环，但还不足以判断长期价值或付费意愿。',
    stats: [['1', '个人表达'], ['1', '活跃日'], ['0', '复习']],
    trigger: '成功提示出现后 12 秒，或用户重播音频一次后；底部轻卡片，可关闭。',
    steps: [
      { key: 'firstHelpful', type: 'scale', label: '即时微反馈 · 1/1', q: '这句英文和音频，对你刚才想表达的意思有帮助吗？', help: '只收集产品质量，不出现会员或价格。', options: ['1 没帮助','2','3','4','5 很有帮助'] },
      { key: 'firstProblem', only: a => Number(a.firstHelpful) <= 3, type: 'single', label: '帮我们改准一点', q: '主要是哪里不符合你的期待？', options: ['表达不够自然','不像我会说的话','中文意思有偏差','音频不自然','我还不确定'] },
      { key: 'firstInvite', only: a => Number(a.firstHelpful) >= 4, type: 'single', label: '下一步', q: '谢谢你的反馈。要不要现在再记下一句真实想说的话？', options: ['好，再记一句','先听听这句','稍后再说'] }
    ]
  },
  {
    id: 'engaged',
    tab: '高频试用',
    state: '试用第 3 天 · 多次使用',
    title: '已经形成自己的小句库',
    copy: '用户体验过生成、聆听和复习，具备判断价值的基础。这是主问卷和软性方案解释的最佳窗口。',
    stats: [['8', '个人表达'], ['3', '活跃日'], ['5', '聆听／复习']],
    trigger: '满足 2 个活跃日、3 条以上个人表达；本次停留超过 90 秒且不在生成中。',
    steps: [
      { key: 'valueScore', type: 'scale', label: '价值确认', q: '到目前为止，Selah 帮你练习「自己真正会用到的英文」的效果如何？', options: ['1 很差','2','3','4','5 很好'] },
      { key: 'pmf', type: 'single', label: '产品契合', q: '如果以后不能继续用 Selah，你会有什么感觉？', options: ['非常失望','有点失望','不失望，因为替代品很多','我还没有足够使用'] },
      { key: 'features', type: 'multi', label: '使用价值', q: '这几天哪些部分真的帮到了你？可多选。', options: ['把中文想法变成自然英文','AI 配音与逐句聆听','复习调度','长文整理成可练习句子','笔记和词汇拆解','循环听'] },
      { key: 'barrier', only: a => a.pmf !== '非常失望' || Number(a.valueScore) <= 3, type: 'multi', label: '阻碍识别', q: '什么会让你之后很难继续用？可多选。', options: ['想不起要输入什么','生成结果不够贴近我','听不懂或跟读困难','没有固定学习时间','价格不确定','担心坚持不下来'] },
      { key: 'improve', only: a => a.pmf !== '非常失望' || Number(a.valueScore) <= 3, type: 'single', optional: true, label: '开放反馈', q: '如果只改一件事，你最希望我们先改什么？', options: ['表达更自然','音频更自然','学习提醒更合适','复习更容易坚持','句子管理更清楚'], open: true },
      { key: 'payIntent', only: a => a.pmf === '非常失望' || Number(a.valueScore) >= 4, type: 'single', label: '持续使用', q: '如果月会员支持每月 300 条个人表达、30000 配音字符、60 分钟转写和 30 次长文整理，你开通 39.9 元月会员的可能性是？', help: '主动续购，不自动扣款；学习已有内容不消耗新增额度。', options: ['肯定会','可能会','需要再想想','大概不会','肯定不会'] },
      { key: 'priceBlocker', only: a => ['需要再想想','大概不会','肯定不会'].includes(a.payIntent), type: 'single', label: '付费阻碍', q: '主要顾虑是什么？', options: ['价格高于预期','还没确认自己会坚持','不确定额度是否够用','想先看到更多学习效果','支付方式不方便','其他'] },
      { key: 'researchConsent', type: 'consent', label: '研究同意', q: '我们是否可以在不展示你原始句子的前提下，把这份反馈用于产品改进汇总？', options: ['同意，用于匿名汇总','只本次保存','不同意'] }
    ]
  },
  {
    id: 'low',
    tab: '低使用续访',
    state: '试用第 5 天 · 使用较少',
    title: '回来看看，但还没形成习惯',
    copy: '用户尚未体验到足够价值。此时直接引导付费会损伤信任，应先诊断激活问题并降低下一步门槛。',
    stats: [['2', '个人表达'], ['1', '活跃日'], ['0', '复习']],
    trigger: '试用第 5 天后回访；不使用启动弹窗，放在 Today 底部的轻量卡片。',
    steps: [
      { key: 'returnGoal', type: 'single', label: '目标确认 · 1/4', q: '你现在最想先用 Selah 解决什么？', options: ['日常口语表达','工作或学习表达','旅行／生活场景','听不懂或发音问题','还没想好'] },
      { key: 'lowReason', type: 'multi', label: '激活诊断 · 2/4', q: '这几天用得少，主要是什么原因？可多选。', options: ['忘记打开','不知道输入什么','操作步骤有点多','生成结果不够想练','音频或聆听体验问题','只是最近太忙'] },
      { key: 'helpPref', type: 'single', label: '帮助方式 · 3/4', q: '哪种帮助最可能让你明天完成一次练习？', options: ['给我 3 个可直接改写的句子','睡前提醒我写一句','按我的场景给示例','先不用提醒'] },
      { key: 'lowOpen', type: 'single', optional: true, label: '补充 · 4/4', q: '还有什么想告诉我们的？', open: true, options: ['暂时没有'] }
    ]
  },
  {
    id: 'blocked',
    tab: '试用受限',
    state: '新增生成当前不可用',
    title: '今天想继续新增内容',
    copy: '服务端返回真实限制后，先解释已有内容仍可学习，再询问付费阻碍。问卷不能伪装成系统提示，也不能逼用户立刻付款。',
    stats: [['24', '个人表达'], ['6', '活跃日'], ['18', '聆听／复习']],
    trigger: '受限提示出现并被用户展开「了解方案」后；如果用户关闭，8 小时内不再追问。',
    steps: [
      { key: 'restrictionUnderstood', type: 'single', label: '限制反馈 · 1/4', q: '刚才的说明是否让你清楚知道：为什么现在不能新增生成，以及哪些内容还能继续学？', options: ['清楚','大概清楚','不清楚'] },
      { key: 'blockedValue', type: 'scale', label: '价值确认 · 2/4', q: '在达到这个限制前，Selah 对你的学习有价值吗？', options: ['1 没有','2','3','4','5 很有价值'] },
      { key: 'blockedReason', type: 'multi', label: '开通顾虑 · 3/4', q: '如果还没开通月会员，主要原因是什么？可多选。', options: ['39.9 元价格需要考虑','担心下个月用不到','额度是否适合我不清楚','想先复习已有内容','支付或续费方式顾虑','功能还不够打动我'] },
      { key: 'planQuestion', type: 'single', label: '方案解释 · 4/4', q: '你希望我们在方案页优先解释什么？', options: ['额度分别能练多久','和免费继续学的区别','暂停或不续购会怎样','具体适合我的使用频率','支付方式与到账'] }
    ]
  },
  {
    id: 'member',
    tab: '会员续期',
    state: '月会员第 24 天',
    title: '这个月的学习是否真的留下来了',
    copy: '对会员不应只推送续费，而要收集成果、净推荐值和功能优先级，用结果决定续购沟通与下个版本路线。',
    stats: [['126', '个人表达'], ['19', '活跃日'], ['84', '复习完成']],
    trigger: '会员第 24 天、用户完成一次复习后出现；不在临期当天用倒计时打断。',
    steps: [
      { key: 'outcome', type: 'single', label: '学习成果 · 1/4', q: '这个月你最明显感受到的变化是什么？', options: ['更敢表达真实想法','能说出更自然的英文','听力或跟读更顺','积累了自己的句库','暂时没有明显变化'] },
      { key: 'nps', type: 'scale', label: '推荐可能 · 2/4', q: '你把 Selah 推荐给同样想练真实表达的朋友的可能性是？', options: ['0','2','4','6','8','10'] },
      { key: 'priority', type: 'multi', label: '功能方向 · 3/4', q: '下个版本你最希望优先加强什么？可多选 2 项。', max: 2, options: ['更多真实场景输入引导','口语跟读评分','循环听自定义','日语母语支持','更细的词汇／语法讲解','导出或打印复习材料'] },
      { key: 'renewal', type: 'single', label: '续购信心 · 4/4', q: '下个月主动续购月会员的可能性是？', options: ['肯定续购','大概会','看使用情况','大概不会','肯定不会'] }
    ]
  }
];

renderPrinciples();
resetRun();
