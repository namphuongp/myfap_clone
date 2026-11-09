import { applyDueTransfers } from "../services/major.service.js";
export function startMajorTransferJob() {
  let running = false;
  const tick = async () => {
    if (running) return;
    running = true;
    try {
      await applyDueTransfers();
    } catch (error) {
      console.error("MAJOR_TRANSFER_JOB", error.code ?? error.message);
    } finally {
      running = false;
    }
  };
  void tick();
  const timer = setInterval(() => void tick(), 60000);
  timer.unref();
  return () => clearInterval(timer);
}
