# Yeti Visualization Algorithm

## Overview

The Yeti visualization is a state machine-based video player that transitions smoothly between intensity states based on the user's velocity. Unlike the Flame and Colors visualizations which update instantly, Yeti uses pre-rendered video transitions to create a more cinematic experience.

## State Definitions

The Yeti visualization has 4 intensity states:
- **State 0**: Idle
- **State 1**: Easy intensity
- **State 2**: Medium intensity
- **State 3**: Hard intensity

### Bucket-to-State Mapping

The velocity buckets map to states as defined in `constants/yeti_state_mapping.json`. The current mapping is:

```
VelocityBucket.IDLE            → State 0
VelocityBucket.DOWNHILL_EASY   → State 1
VelocityBucket.UPHILL_EASY     → State 1
VelocityBucket.DOWNHILL_MEDIUM → State 2
VelocityBucket.UPHILL_MEDIUM   → State 2
VelocityBucket.DOWNHILL_HARD   → State 3
VelocityBucket.UPHILL_HARD     → State 3
```

**Note**: Future versions may distinguish between uphill and downhill for the same difficulty level. The algorithm is designed to support separate mappings if needed.

## Video Naming Convention

Videos are named using the pattern: `{fromState} to {toState} {variant}.mp4`

Examples:
- `0 to 1.mp4` - Transition from idle to easy
- `1 to 1 a.mp4` - Easy staying at easy (variant a)
- `2 to 3.mp4` - Transition from medium to hard

Multiple variants of same-state loops provide visual variety.

## State Transition Algorithm

### Gradual Transitions

The key principle is **gradual transitions** - the Yeti only moves one state at a time, even if the user's velocity has jumped multiple states.

**Example**: If the user is in State 0 (idle) and their velocity jumps to the medium bucket (State 2):
1. Play `0 to 1.mp4` (move from idle to easy)
2. After that video ends, check velocity again
3. If still in medium bucket, play `1 to 2.mp4` (move from easy to medium)
4. After that video ends, check velocity again
5. If still in medium bucket, play random `2 to 2` variant

This creates smooth, believable transitions rather than jarring jumps.

### Algorithm Steps

At the end of each video playback:

1. **Sample Current Velocity**: Determine the current velocity bucket
2. **Map to Target State**: Use the bucket-to-state mapping to get target state
3. **Calculate Next State**: Determine the next state based on current state and target state:
   ```
   if targetState > currentState:
       nextState = currentState + 1
   else if targetState < currentState:
       nextState = currentState - 1
   else:
       nextState = currentState  // Stay in same state
   ```

4. **Select Video**: Choose the video file for the transition:
   - If moving states: Select `{currentState} to {nextState}.mp4`
   - If staying: Randomly select from available variants
     - e.g., for state 1: randomly choose `1 to 1 a.mp4` or `1 to 1 b.mp4`

5. **Update Current State**: Set `currentState = nextState`

6. **Play Video**: Start playback and repeat from step 1 when complete

### Pseudocode

```
currentState = 0  // Start at idle
videosPlaying = true

while videosPlaying:
    // Play current video
    video = selectVideo(currentState, nextState)
    playVideoToCompletion(video)

    // Determine next transition
    currentBucket = getCurrentVelocityBucket()
    targetState = mapBucketToState(currentBucket)

    if targetState > currentState:
        nextState = currentState + 1
    else if targetState < currentState:
        nextState = currentState - 1
    else:
        nextState = currentState

    currentState = nextState

function selectVideo(fromState, toState):
    if fromState == toState:
        // Same state - pick random variant
        variants = getVariantsForTransition(fromState, toState)
        return randomChoice(variants)
    else:
        // State transition - use primary transition video
        return getTransitionVideo(fromState, toState)
```

## Video Requirements

### Required Transitions

All one-step transitions must have at least one video:
- **Upward**: 0→1, 1→2, 2→3
- **Downward**: 3→2, 2→1, 1→0
- **Same-state loops**: 0→0, 1→1, 2→2, 3→3 (at least one variant each)

### Optional Variants

Multiple variants for same-state loops add variety:
- `0 to 0 a.mp4`, `0 to 0 b.mp4`, `0 to 0 c.mp4`
- `1 to 1 a.mp4`, `1 to 1 b.mp4`
- `2 to 2 a.mp4`, `2 to 2 b.mp4`
- `3 to 3 a.mp4`, `3 to 3 b.mp4`

## Implementation Notes

### iOS
- Use `AVPlayer` and `AVPlayerLayer` for video playback
- Monitor `AVPlayerItemDidPlayToEndTime` notification to detect video completion
- Bundle videos in app using Xcode asset catalog or Resources folder

### Android
- Use `VideoView` or `ExoPlayer` for video playback
- Listen for `OnCompletionListener` to detect video completion
- Bundle videos in `res/raw/` or `assets/` folder

### Performance
- Videos should be optimized for mobile playback (H.264 codec recommended)
- Consider pre-loading next video during current playback to minimize transition gaps
- Videos should loop seamlessly when staying in same state

### Error Handling
- If a required transition video is missing, log error and fall back to staying in current state
- If no variants exist for same-state loop, replay the single available video
- If video fails to load, consider falling back to Flame or Colors visualization

## Future Enhancements

1. **Separate Uphill/Downhill States**: May expand to 6 or 8 states with separate visuals for uphill vs downhill
2. **Diagonal Transitions**: If uphill/downhill become separate, may need videos like "downhill easy → uphill medium"
3. **Speed Multiplier**: Could adjust playback speed based on how far the target state is from current
4. **Crossfading**: Blend between videos for ultra-smooth transitions
5. **Dynamic Loading**: Stream videos from server instead of bundling all in app
