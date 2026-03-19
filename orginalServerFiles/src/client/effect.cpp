#include "effect.h"
#include "map.h"
#include "game.h"
#include <framework/core/graphicalapplication.h>
#include <framework/core/eventdispatcher.h>
#include <framework/util/extras.h>

void Effect::setEffect(uint16 effectId)
{
    if (!g_things.isValidDatId(effectId, ThingCategoryEffect)) {
    }

    setId(effectId);
    m_animationTimer.restart();

    int duration = 0;
    if (g_game.getFeature(Otc::GameEnhancedAnimations)) {
        duration = getThingType()->getAnimator() ? getThingType()->getAnimator()->getTotalDuration() : 1000;
    } else {
        duration = EFFECT_TICKS_PER_FRAME;
        duration *= getAnimationPhases();
    }
}



void Effect::draw(const Point& dest, int offsetX, int offsetY, bool animate, LightView* lightView)
{
    if (m_id == 0)
        return;

    if (animate) {
        if (g_game.getFeature(Otc::GameEnhancedAnimations) && rawGetThingType()->getAnimator()) {
            // Use separate getPhaseAt for independent animation phases
            m_animationPhase = std::max<int>(0, rawGetThingType()->getAnimator()->getPhaseAt(m_animationTimer, m_animationPhase));
        } else {
            int ticks = EFFECT_TICKS_PER_FRAME;
            if (m_id == 33) {
                ticks <<= 2; // Special case for specific effect
            }

            m_animationPhase = std::max<int>(0, std::min<int>((int)(m_animationTimer.ticksElapsed() / ticks), getAnimationPhases() - 1));
        }
    }

    int xPattern = m_position.x % getNumPatternX();
    if (xPattern < 0)
        xPattern += getNumPatternX();

    int yPattern = m_position.y % getNumPatternY();
    if (yPattern < 0)
        yPattern += getNumPatternY();

    // Aplicar deslocamento de efeito
    Point effectDisplacement = rawGetThingType()->getEffectDisplacement();

    // Aplicar a lógica de transparência
    Color tmpColor = Color::white;
    tmpColor.setAlpha(static_cast<float>(g_app.getAlphaEffect()));

    // Chamar o método de desenho com a cor ajustada
    rawGetThingType()->draw(dest + effectDisplacement, 0, xPattern, yPattern, 0, m_animationPhase, tmpColor, lightView);
}



void Effect::onAppear()
{
    m_animationTimer.restart();

    int duration = 0;
    if(g_game.getFeature(Otc::GameEnhancedAnimations)) {
        duration = getThingType()->getAnimator() ? getThingType()->getAnimator()->getTotalDuration() : 1000;
    } else {
        duration = EFFECT_TICKS_PER_FRAME;

        if(m_id == 33) {
            duration <<= 2;
        }

        duration *= getAnimationPhases();
    }

    auto self = asEffect();
    g_dispatcher.scheduleEvent([self]() { g_map.removeThing(self); }, duration);
}

void Effect::setId(uint32 id)
{
    if (!g_things.isValidDatId(id, ThingCategoryEffect)) {
        id = 0;
    }
    m_id = id;
}

const ThingTypePtr& Effect::getThingType()
{
    return g_things.getThingType(m_id, ThingCategoryEffect);
}

ThingType* Effect::rawGetThingType()
{
    return g_things.rawGetThingType(m_id, ThingCategoryEffect);
}
