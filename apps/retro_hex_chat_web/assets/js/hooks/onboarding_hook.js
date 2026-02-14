/**
 * LiveView hook for first-run onboarding detection.
 *
 * On mount, checks localStorage via the onboarding lib and pushes
 * a `check_onboarding` event to the server with the first-visit flag.
 * Listens for `mark_onboarding_complete` from the server to persist
 * the completion state.
 */
import { isOnboardingComplete, markOnboardingComplete } from "../lib/onboarding.js";

const OnboardingHook = {
  mounted() {
    const complete = isOnboardingComplete();
    this.pushEvent("check_onboarding", { first_visit: !complete });

    this.handleEvent("mark_onboarding_complete", () => {
      markOnboardingComplete();
    });
  },
};

export default OnboardingHook;
